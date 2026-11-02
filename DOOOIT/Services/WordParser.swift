import Foundation

struct ParsedWord: Identifiable, Hashable {
    var id = UUID()
    var term: String
    var meaning: String
    /// 흐리게 읽혔거나 철자가 이상한 단어 (확인 화면에서 표시)
    var unsure = false
}

/// OCR 결과를 "영어 단어 - 한글 뜻" 쌍으로 변환
enum WordParser {
    static func parse(_ lines: [OCRLine]) -> [ParsedWord] {
        // 0) 두 단으로 나뉜 페이지는 왼쪽 단 → 오른쪽 단 순서로 따로 읽음 (옆 단 글자가 한 줄로 섞이지 않게)
        let words = splitColumns(lines).flatMap(parseColumn)
        // 3) 같은 단어는 뜻을 합쳐서 하나로
        var merged: [ParsedWord] = []
        for word in words where !word.term.isEmpty {
            if let i = merged.firstIndex(where: { $0.term.lowercased() == word.term.lowercased() }) {
                if merged[i].meaning.isEmpty { merged[i].meaning = word.meaning }
                else if !word.meaning.isEmpty && !merged[i].meaning.contains(word.meaning) { merged[i].meaning += ", " + word.meaning }
            } else {
                merged.append(word)
            }
        }
        // 4) 흐리게 읽힌 줄에서 나온 단어는 "확인 필요"
        for i in merged.indices {
            let term = merged[i].term.lowercased()
            let source = lines.filter { fixOCRTerm($0.text).lowercased().contains(term) }
            if let worst = source.map(\.confidence).min(), worst < 0.5 { merged[i].unsure = true }
        }
        return merged
    }

    /// 두 단(왼쪽·오른쪽에 각각 "단어 + 뜻")으로 된 페이지면 단마다 나눔.
    /// "영어 | 한글" 두 칸짜리 표는 한 단이므로 나누지 않음 (양쪽 모두 영어와 한글이 있어야 두 단)
    static func splitColumns(_ lines: [OCRLine]) -> [[OCRLine]] {
        guard lines.count >= 6 else { return [lines] }
        func hasHangul(_ t: String) -> Bool { t.range(of: "[가-힣]", options: .regularExpression) != nil }
        func hasLatin(_ t: String) -> Bool { t.range(of: "[A-Za-z]{2,}", options: .regularExpression) != nil }
        func isMixedColumn(_ side: [OCRLine]) -> Bool {
            guard side.count >= 3 else { return false }
            let hangul = side.filter { hasHangul($0.text) }.count
            let latin = side.filter { hasLatin($0.text) }.count
            return hangul * 4 >= side.count && latin * 4 >= side.count
        }
        var best: (x: Double, crossing: Int)?
        var x = 0.3
        while x <= 0.7 {
            let crossing = lines.filter { Double($0.box.minX) < x - 0.005 && Double($0.box.maxX) > x + 0.005 }.count
            if crossing * 10 <= lines.count {
                let left = lines.filter { Double($0.box.maxX) <= x + 0.005 }
                let right = lines.filter { Double($0.box.minX) >= x - 0.005 }
                // 양쪽 단이 같은 높이에 나란히 있어야 함
                let leftTop: CGFloat = left.map(\.box.maxY).max() ?? 0
                let rightTop: CGFloat = right.map(\.box.maxY).max() ?? 0
                let leftBottom: CGFloat = left.map(\.box.minY).min() ?? 1
                let rightBottom: CGFloat = right.map(\.box.minY).min() ?? 1
                let overlap = Double(min(leftTop, rightTop) - max(leftBottom, rightBottom))
                if isMixedColumn(left), isMixedColumn(right), overlap > 0.2 {
                    let better: Bool
                    if let current = best {
                        better = crossing < current.crossing || (crossing == current.crossing && abs(x - 0.5) < abs(current.x - 0.5))
                    } else {
                        better = true
                    }
                    if better { best = (x, crossing) }
                }
            }
            x += 0.01
        }
        guard let split = best?.x else { return [lines] }
        let left = lines.filter { Double($0.box.midX) < split }
        let right = lines.filter { Double($0.box.midX) >= split }
        return [left, right]
    }

    /// 한 단 읽기: 같은 높이 글자를 한 줄로 묶은 뒤 단어·뜻으로
    static func parseColumn(_ lines: [OCRLine]) -> [ParsedWord] {
        // 1) 같은 높이(행)에 있는 글자 묶기
        let sorted = lines.sorted { $0.box.midY > $1.box.midY }
        var rows: [[OCRLine]] = []
        for line in sorted {
            if let reference = rows.last?.first,
               abs(reference.box.midY - line.box.midY) < max(reference.box.height, line.box.height) * 0.6 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }

        let texts = rows.map { row in row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
        // 시중 단어장(표제어 + [발음] + 품사 + 뜻 + 예시 구·예문)은 품사 표시를 기준으로 읽음
        return isBookPage(texts) ? parseBook(texts) : parseList(texts)
    }

    /// 영어 낱말 속에 끼어든 숫자·기호를 비슷한 글자로 ("app1e" → "apple", "5mall" → "small", "c0ntinent" → "continent")
    /// 숫자만 있는 낱말(번호·쪽수)은 그대로 둠
    static func fixOCRTerm(_ text: String) -> String {
        let map: [Character: Character] = ["0": "o", "1": "l", "5": "s", "|": "l", "$": "s"]
        return text.split(separator: " ", omittingEmptySubsequences: false).map { token -> String in
            let letters = token.filter { $0.isASCII && $0.isLetter }.count
            guard letters >= 2, token.contains(where: { map[$0] != nil }),
                  !token.contains(where: { $0.isNumber && map[$0] == nil }) else { return String(token) }
            var chars = Array(token)
            for i in chars.indices {
                guard let replacement = map[chars[i]] else { continue }
                let before = i > 0 && chars[i - 1].isASCII && chars[i - 1].isLetter
                let after = i + 1 < chars.count && chars[i + 1].isASCII && chars[i + 1].isLetter
                if before || after { chars[i] = replacement }
            }
            return String(chars)
        }.joined(separator: " ")
    }

    /// 단순한 단어 목록 ("apple 사과" 한 줄씩, 또는 뜻이 다음 줄)
    static func parseList(_ texts: [String]) -> [ParsedWord] {
        // 2) 행마다 단어/뜻 분리
        var result: [ParsedWord] = []
        var pendingTerm: String?
        /// 바로 앞 줄이 예문이었으면, 다음 한글 줄은 그 예문의 해석이라 뜻에 붙이지 않음
        var afterExample = false

        for text in texts {
            // 예문(영어 문장)과 예문 해석은 단어·뜻이 아님
            if isExampleSentence(text) {
                afterExample = true
                continue
            }
            let (term, meaning) = split(text)
            if term.isEmpty, !meaning.isEmpty, afterExample || looksLikeKoreanSentence(meaning) {
                afterExample = false
                continue
            }
            afterExample = false

            switch (term.isEmpty, meaning.isEmpty) {
            case (false, false):
                result.append(ParsedWord(term: term, meaning: meaning))
                pendingTerm = nil
            case (false, true):
                // 뜻이 다음 줄에 있는 세로형 단어장
                if let pending = pendingTerm {
                    result.append(ParsedWord(term: pending, meaning: ""))
                }
                pendingTerm = term
            case (true, false):
                if let pending = pendingTerm {
                    result.append(ParsedWord(term: pending, meaning: meaning))
                    pendingTerm = nil
                } else if !result.isEmpty {
                    // 앞 단어 뜻의 연장
                    let last = result[result.count - 1]
                    result[result.count - 1].meaning = last.meaning.isEmpty ? meaning : last.meaning + ", " + meaning
                }
            case (true, true):
                break
            }
        }
        if let pending = pendingTerm {
            result.append(ParsedWord(term: pending, meaning: ""))
        }
        return result.map { ParsedWord(term: $0.term, meaning: cleanMeaning($0.meaning)) }
    }

    // MARK: - 시중 단어장 (품사 표시 기준)

    /// 품사 표시: 명 동 형 부 전 접 대 감 (괄호·] 붙어도), n. v. adj. adv. …
    static func isPOS(_ word: String) -> Bool {
        word.range(of: #"^[\(\[]?(명|동|형|부|전|접|대|감|자|타)[\]\)\.:]?$"#, options: .regularExpression) != nil
            || word.range(of: #"^\(?(n|v|vt|vi|a|adj|adv|ad|prep|conj|pron|int)\.\)?$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// [발음]·(발음) (한글이 없는 괄호), 번호·쪽수, 낱자 자모 지우기
    static func stripNoise(_ text: String) -> String {
        var t = text
        t = t.replacingOccurrences(of: #"[\[\(][^\]\)가-힣]{1,30}[\]\)]"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?<![A-Za-z가-힣])\d{1,4}(?![A-Za-z가-힣])"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?<![가-힣])[ㄱ-ㅎㅏ-ㅣ]+(?![가-힣])"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"[□■☐☑✓✔•…]+"#, with: " ", options: .regularExpression)
        return t
    }

    static func isBookPage(_ texts: [String]) -> Bool {
        let words = texts.flatMap { stripNoise($0).split(separator: " ").map(String.init) }
        let pos = words.filter(isPOS).count
        let brackets = texts.reduce(0) { $0 + $1.matches(of: #/\[[^\]가-힣]{2,}\]/#).count }
        return pos >= 2 || brackets >= 2
    }

    private enum Piece { case english([String]), korean([String], pos: Bool), slash, lineBreak }

    /// 품사 뒤의 뜻을 그 앞(또는 같은 줄 바로 뒤)의 영어 한 낱말에 붙임. 예시 구·예문·해석은 버림
    static func parseBook(_ texts: [String]) -> [ParsedWord] {
        // 1) 글을 영어 덩어리 / 한글 덩어리(품사로 시작하면 품사 덩어리) / 줄바꿈·"/" 으로 나눔
        var pieces: [Piece] = []
        func push(_ word: String) {
            let hasHangul = word.range(of: "[가-힣]", options: .regularExpression) != nil
            let hasLatin = word.range(of: "[A-Za-z]", options: .regularExpression) != nil
            if isPOS(word) {
                pieces.append(.korean([word], pos: true))
            } else if hasHangul {
                if case .korean(let words, let pos)? = pieces.last { pieces[pieces.count - 1] = .korean(words + [word], pos: pos) }
                else { pieces.append(.korean([word], pos: false)) }
            } else if hasLatin {
                if case .english(let words)? = pieces.last { pieces[pieces.count - 1] = .english(words + [word]) }
                else { pieces.append(.english([word])) }
            } else if case .korean(let words, let pos)? = pieces.last {
                // 기호(~, 쉼표 등)는 앞의 뜻에 붙임
                pieces[pieces.count - 1] = .korean(words + [word], pos: pos)
            }
        }
        for text in texts {
            for raw in stripNoise(text).components(separatedBy: " ") where !raw.isEmpty {
                if raw == "/" { pieces.append(.slash); continue }
                push(raw)
            }
            pieces.append(.lineBreak)
        }

        // 2) 품사 덩어리마다 표제어 찾기
        var result: [ParsedWord] = []
        var used = Set<Int>()
        var lastOwner: (index: Int, piece: Int)?
        for (i, piece) in pieces.enumerated() {
            guard case .korean(let words, true) = piece else { continue }
            let meaning = cleanMeaning(words.joined(separator: " "))
            // 바로 앞이 같은 단어의 다른 품사면 이어 붙임 ("instant 형 즉각적인 명 순간")
            if let owner = lastOwner, owner.piece == i - 1 {
                result[owner.index].meaning += ", " + meaning
                lastOwner = (owner.index, i)
                continue
            }
            var owner: Int?
            // 앞 칸의 영어 한 낱말 (표제어만 한 줄에 따로 있으면 줄바꿈 하나 건너서)
            let back: Int? = {
                if i > 0, case .english = pieces[i - 1] { return i - 1 }
                if i > 1, case .lineBreak = pieces[i - 1], case .english = pieces[i - 2] { return i - 2 }
                return nil
            }()
            if let back, case .english(let before) = pieces[back], before.count == 1, !used.contains(back) {
                owner = back
            } else if i + 1 < pieces.count, case .english(let after) = pieces[i + 1], after.count == 1, !used.contains(i + 1) {
                // 같은 줄 바로 뒤의 낱말 ("명 대륙 continent"), 단 그 낱말 뒤에 자기 품사가 바로 오면 다음 단어의 것
                let nextIsPOS: Bool = { if i + 2 < pieces.count, case .korean(_, true) = pieces[i + 2] { return true }; return false }()
                if !nextIsPOS { owner = i + 1 }
            }
            guard let owner, case .english(let termWords) = pieces[owner] else { lastOwner = nil; continue }
            let term = cleanTerm(termWords.joined(separator: " "))
            guard !term.isEmpty else { continue }
            used.insert(owner)
            result.append(ParsedWord(term: term, meaning: meaning))
            lastOwner = (result.count - 1, i)
        }
        // 3) 품사 표시 없이 "영어 한 낱말 + 뜻"만 있는 줄도 단어로 (예시 구·예문은 여러 낱말이라 빠짐)
        for (i, piece) in pieces.enumerated() where !used.contains(i) {
            guard case .english(let words) = piece, words.count == 1, i + 1 < pieces.count,
                  case .korean(let meaningWords, false) = pieces[i + 1] else { continue }
            let meaning = cleanMeaning(meaningWords.joined(separator: " "))
            let term = cleanTerm(words[0])
            if !term.isEmpty, !meaning.isEmpty, !looksLikeKoreanSentence(meaning) { result.append(ParsedWord(term: term, meaning: meaning)) }
        }
        return result
    }

    /// 뜻 정리: 발음·번호 지우기, 예문 해석 같은 문장 조각 빼기, 끝의 영어 낱말 떼기
    static func cleanMeaning(_ raw: String) -> String {
        var t = stripExample(from: stripNoise(raw))
        t = t.replacingOccurrences(of: #"\s+[A-Za-z][A-Za-z\-']*\s*$"#, with: "", options: .regularExpression)
        let parts = t.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !looksLikeKoreanSentence($0) }
        t = parts.joined(separator: ", ")
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: CharacterSet(charactersIn: " ,/"))
    }

    /// "1. apple n. 사과, 능금" → ("apple", "n. 사과, 능금")
    static func split(_ raw: String) -> (term: String, meaning: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 번호, 체크박스 제거
        s = s.replacingOccurrences(of: #"^[\(\[]?\d{1,4}[\.\)\]:]?\s*"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^[□■☐☑✓✔•·\-\*]+\s*"#, with: "", options: .regularExpression)

        guard let hangulRange = s.range(of: #"[가-힣ㄱ-ㅎ]"#, options: .regularExpression) else {
            return (cleanTerm(s), "")
        }

        var termPart = String(s[..<hangulRange.lowerBound])
        var meaningPart = String(s[hangulRange.lowerBound...])

        // 단어 뒤에 붙은 품사 표시는 뜻 쪽으로 이동 (n. v. adj. ...)
        if let posRange = termPart.range(
            of: #"\s(n|v|vt|vi|a|ad|adj|adv|prep|conj|pron|int|phr)\.?\s*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            let pos = termPart[posRange].trimmingCharacters(in: .whitespaces)
            termPart = String(termPart[..<posRange.lowerBound])
            meaningPart = pos + " " + meaningPart
        }

        // 뜻 뒤에 붙은 예문 떼기 ("용감한 She was brave." / "용감한 예) …" / "용감한 ex. …")
        meaningPart = stripExample(from: meaningPart)
        meaningPart = meaningPart.trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleanTerm(termPart), meaningPart)
    }

    // MARK: 예문 거르기

    /// 예문 표시 (뒤에 문장부호가 있어야 함: "exact", "example" 같은 단어는 해당 없음)
    private static let exampleMarkers = [#"^(e\.\s?g\.?|eg\.|ex[.):]|example\s*[:)]|예\)|예:|예문|ⓔ|▶|►|→|=>)"#]

    /// 영어 예문인지: 예문 표시로 시작하거나, 문장부호로 끝나는 문장, 또는 대문자로 시작하고 주어·동사가 있는 3낱말 이상
    /// ("give up", "be good at", "a lot of" 같은 숙어는 단어로 남김)
    static func isExampleSentence(_ raw: String) -> Bool {
        var s = raw.trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: #"^[\(\[]?\d{1,4}[\.\)\]:]?\s*"#, with: "", options: .regularExpression)
        let lower = s.lowercased()
        if exampleMarkers.contains(where: { lower.range(of: $0, options: .regularExpression) != nil }) { return true }
        // 한글이 섞인 줄은 "단어 뜻" 줄이므로 여기서는 예문으로 보지 않음 (뜻 뒤 예문은 stripExample이 처리)
        guard s.range(of: "[가-힣]", options: .regularExpression) == nil else { return false }
        let words = s.split(separator: " ").filter { $0.contains(where: \.isLetter) }
        guard words.count >= 3 else { return false }
        if let last = s.last, ".?!\"”".contains(last) { return true }
        let first = String(words[0])
        let function: Set<String> = ["i", "you", "he", "she", "it", "we", "they", "this", "that", "there", "my", "his", "her", "our", "their",
                                     "is", "are", "was", "were", "am", "will", "can", "do", "does", "did", "have", "has", "had", "the"]
        let hasFunction = words.dropFirst().contains { function.contains($0.lowercased()) } || function.contains(first.lowercased())
        return first.first?.isUppercase == true && hasFunction && words.count >= 4
    }

    /// 한글 문장인지 (예문 해석): 마침표로 끝나거나, 띄어쓰기가 많고 "~다/~요"로 끝남 ("포기하다" 같은 뜻은 아님)
    static func looksLikeKoreanSentence(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard s.count >= 8, !s.contains(",") else { return false }
        if s.hasSuffix(".") || s.hasSuffix("?") || s.hasSuffix("!") { return true }
        let spaces = s.filter { $0 == " " }.count
        return spaces >= 3 && (s.hasSuffix("다") || s.hasSuffix("요"))
    }

    /// 뜻 뒤에 이어 붙은 예문 잘라내기
    static func stripExample(from meaning: String) -> String {
        var m = meaning
        // 예문 표시가 나오면 거기서 자름
        for marker in [#"\s(e\.\s?g\.?|eg\.|ex[.):]|예\)|예:|예문|ⓔ|▶|►|→)"#] {
            if let range = m.range(of: marker, options: [.regularExpression, .caseInsensitive]) { m = String(m[..<range.lowerBound]) }
        }
        // 영어 낱말이 세 개 이상 이어지면 예문으로 보고 자름 ("용감한 She was brave.")
        if let range = m.range(of: #"\s[A-Za-z][A-Za-z'’]*(\s+[A-Za-z][A-Za-z'’,]*){2,}"#, options: .regularExpression) {
            m = String(m[..<range.lowerBound])
        }
        return m.trimmingCharacters(in: .whitespaces)
    }

    private static func cleanTerm(_ input: String) -> String {
        let raw = fixOCRTerm(input)
        let allowed = CharacterSet.letters.union(.whitespaces).union(CharacterSet(charactersIn: "-'’~"))
        let filtered = String(raw.unicodeScalars.filter { allowed.contains($0) })
        let term = filtered
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-~")))

        // 영어 글자가 있어야 하고, 예문처럼 긴 문장은 제외
        guard term.range(of: "[A-Za-z]", options: .regularExpression) != nil else { return "" }
        guard term.range(of: "[가-힣]", options: .regularExpression) == nil else { return "" }
        let wordCount = term.split(separator: " ").count
        guard wordCount <= 4, term.count <= 40 else { return "" }
        return term
    }
}

/// 단어 시험 채점
enum AnswerChecker {
    private static let separators = CharacterSet(charactersIn: ",;/·、\n")

    static func normalizeMeaning(_ s: String) -> String {
        var t = s.lowercased()
        // 괄호 안 설명, 품사 표시 제거
        t = t.replacingOccurrences(of: #"\([^)]*\)|\[[^\]]*\]"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\b(n|v|vt|vi|a|ad|adj|adv|prep|conj|pron|int)\."#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"[\s~\.\-!?'"…]"#, with: "", options: .regularExpression)
        return t
    }

    static func checkMeaning(_ input: String, answer: String) -> Bool {
        let given = normalizeMeaning(input)
        guard !given.isEmpty else { return false }
        if given == normalizeMeaning(answer) { return true }

        let candidates = answer
            .components(separatedBy: separators)
            .map(normalizeMeaning)
            .filter { !$0.isEmpty }

        return candidates.contains { candidate in
            if candidate == given { return true }
            // "사과" ↔ "사과나무", "빠르게" ↔ "빠른" 정도는 허용
            guard candidate.count >= 2, given.count >= 2 else { return false }
            return candidate.contains(given) || given.contains(candidate)
        }
    }

    static func checkTerm(_ input: String, answer: String) -> Bool {
        func normalize(_ s: String) -> String {
            s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .replacingOccurrences(of: "’", with: "'")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let given = normalize(input)
        guard !given.isEmpty else { return false }
        return given == normalize(answer)
    }
}

/// 수학 오답 자동 채점 (정답이 있을 때만)
enum MathGrader {
    /// 문제 사진 텍스트에서 "정답: 3" / "답 ④" 같은 표기를 찾음
    static func extractAnswer(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"(?:정답|답)\s*[:：)]?\s*([^\n]+)"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        let value = text[r].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : String(value.prefix(30))
    }

    static func normalize(_ s: String) -> String {
        let circled: [Character: String] = ["①": "1", "②": "2", "③": "3", "④": "4", "⑤": "5",
                                            "⑥": "6", "⑦": "7", "⑧": "8", "⑨": "9", "⑩": "10"]
        var t = ""
        for ch in s.lowercased() {
            if let mapped = circled[ch] { t += mapped } else { t.append(ch) }
        }
        t = t.replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "번", with: "")
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
        if t.hasPrefix("x=") || t.hasPrefix("y=") { t.removeFirst(2) }
        return t
    }

    private static func number(_ s: String) -> Double? {
        if let d = Double(s) { return d }
        let parts = s.split(separator: "/")
        if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]), b != 0 { return a / b }
        return nil
    }

    /// nil이면 자동 채점 불가 (정답 없음)
    static func grade(myAnswer: String, correctAnswer: String) -> Bool? {
        let mine = normalize(myAnswer)
        let answer = normalize(correctAnswer)
        guard !mine.isEmpty, !answer.isEmpty else { return nil }
        if let a = number(mine), let b = number(answer) {
            return abs(a - b) < 1e-9
        }
        return mine == answer
    }
}
