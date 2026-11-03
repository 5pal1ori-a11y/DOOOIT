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
        // 4) 흐리게 읽힌 줄에서 나온 단어, 숫자·기호를 글자로 고친 단어는 "확인 필요"
        for i in merged.indices {
            let pattern = termPattern(merged[i].term)
            let sources = lines.filter { fixOCRTerm($0.text).range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
            if let worst = sources.map(\.confidence).min(), worst < 0.5 { merged[i].unsure = true }
            if !sources.isEmpty, !sources.contains(where: { $0.text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }) {
                merged[i].unsure = true
            }
        }
        return merged
    }

    /// 단어가 다른 낱말 속 글자로 잡히지 않게 ("run"이 "brunch"에 걸리지 않게)
    private static func termPattern(_ term: String) -> String {
        let words = term.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }
        return "(?<![A-Za-z])" + words.joined(separator: #"\s+"#) + "(?![A-Za-z])"
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
                // 양쪽 단이 같은 높이에 나란히 있어야 함 (짧은 단의 절반 이상 겹침)
                let leftTop: CGFloat = left.map(\.box.maxY).max() ?? 0
                let rightTop: CGFloat = right.map(\.box.maxY).max() ?? 0
                let leftBottom: CGFloat = left.map(\.box.minY).min() ?? 1
                let rightBottom: CGFloat = right.map(\.box.minY).min() ?? 1
                let overlap = Double(min(leftTop, rightTop) - max(leftBottom, rightBottom))
                let shorter = Double(min(leftTop - leftBottom, rightTop - rightBottom))
                if isMixedColumn(left), isMixedColumn(right), overlap > 0.1, overlap > shorter * 0.5 {
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

        let raw = rows.map { row in row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
        // 유의어·반의어 줄은 통째로 버림 ("= glad 기쁜", "유의어 glad", "Syn. glad", "glad, joyful, cheerful")
        // "유의어" 같은 제목 줄 바로 아래의 영어만 있는 줄도 유의어 목록으로 봄
        var kept: [String] = []
        var inSynonymBlock = false
        for line in raw {
            if isSynonymHeading(line) { inSynonymBlock = true; continue }
            if isSynonymLine(line) { continue }
            // 시중 단어장의 덧붙인 줄: 파생어·관련 표현(+), 예시 구(•), 영영풀이, 복수형(복), 동사 변화형(oversaw-overseen)
            if isExtraLine(line) { continue }
            if inSynonymBlock, line.range(of: "[가-힣]", options: .regularExpression) == nil, line.contains(where: \.isLetter) { continue }
            inSynonymBlock = false
            kept.append(line)
        }
        let joined = kept.map(normalizeRow)
        // 머리말·꼬리말·쪽수, 유의어만 남은 빈 줄은 버림
        var texts: [String] = []
        for (i, text) in joined.enumerated() where !text.trimmingCharacters(in: .whitespaces).isEmpty {
            if !isHeader(text, next: i + 1 < joined.count ? joined[i + 1] : nil) { texts.append(text) }
        }
        // 시중 단어장(표제어 + [발음] + 품사 + 뜻 + 예시 구·예문)은 품사 표시를 기준으로 읽음
        let parsed = cleanEntries(isBookPage(texts) ? parseBook(texts) : parseList(texts))
        // 표제어에 번호(541, 542 …)가 붙은 단어장: 번호 붙은 표제어만 (파생어·예시 구·변화형은 번호가 없음)
        return keepNumberedHeads(parsed, heads: numberedHeads(raw))
    }

    // MARK: - 단어장의 덧붙인 줄 (표제어가 아닌 것)

    /// 파생어·관련 표현(+ ultimate 형 최종의), 예시 구(• a compact camera 소형 카메라), 영영풀이, 복수형(복 phenomena),
    /// 동사 변화형(oversaw-overseen) 줄은 단어로 넣지 않음
    static func isExtraLine(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        if t.range(of: #"^[+＋✚➕]"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"영\s?영\s?풀\s?이|영풀이|영영 ?뜻"#, options: .regularExpression) != nil { return true }
        // 점 뒤에 영어 두 낱말 이상 (예시 구) — "· apple 사과"처럼 한 낱말은 목록이라 그대로
        if t.range(of: #"^[•·∙●◦▪]\s*[A-Za-z][A-Za-z'’\-]*\s+[A-Za-z]"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"^(복|복수|pl\.)\s*[:)]?\s*[A-Za-z]"#, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        // 영어만 있는 "oversaw-overseen" · "ran - run" (과거형-과거분사)
        if t.range(of: "[가-힣]", options: .regularExpression) == nil,
           t.range(of: #"^[A-Za-z]{2,}\s*[-–/]\s*[A-Za-z]{2,}(\s*[-–/]\s*[A-Za-z]{2,})?$"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// 줄 맨 앞 번호 뒤의 영어 표제어 ("541 ultimately [ʌ́ltimətli]" → ultimately, "12. give up 포기하다" → give up)
    static func numberedHeads(_ rows: [String]) -> Set<String> {
        var heads = Set<String>()
        let pattern = #"^\s*[\[(]?(\d{1,4})[\])\.]?\s*[□☐■ㅁ\s]*([A-Za-z][A-Za-z'’\-]*(?:\s+[a-z][A-Za-z'’\-]*){0,3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return heads }
        for row in rows {
            guard let m = regex.firstMatch(in: row, range: NSRange(row.startIndex..., in: row)),
                  let r = Range(m.range(at: 2), in: row) else { continue }
            heads.insert(String(row[r]).trimmingCharacters(in: .whitespaces).lowercased())
        }
        return heads
    }

    /// 번호 붙은 표제어가 절반 이상인 단어장: 번호 없는 것 중 덧붙인 것으로 보이는 것만 뺌
    /// (여러 낱말 예시 구·숙어 "in brief", 변화형 "oversaw-overseen", 표제어와 뿌리가 같은 파생어·복수형 "ultimate"·"phenomena")
    /// 번호를 잘못 읽은 표제어(efficient)는 남김
    static func keepNumberedHeads(_ words: [ParsedWord], heads: Set<String>) -> [ParsedWord] {
        guard heads.count >= 4, !words.isEmpty else { return words }
        func isHead(_ t: String) -> Bool { heads.contains(t) || heads.contains { $0.hasPrefix(t + " ") } }
        let numbered = words.filter { isHead($0.term.lowercased()) }
        guard numbered.count >= 4, Double(numbered.count) / Double(words.count) >= 0.5 else { return words }
        let singleHeads = heads.map { $0.split(separator: " ").first.map(String.init) ?? $0 }
        func sameRoot(_ a: String, _ b: String) -> Bool {
            guard a != b else { return false }
            let common = zip(a, b).prefix { $0 == $1 }.count
            return common >= 5 && Double(common) >= 0.7 * Double(min(a.count, b.count))
        }
        return words.filter { word in
            let t = word.term.lowercased()
            if isHead(t) { return true }
            if t.contains(" ") || t.contains("-") { return false }
            if singleHeads.contains(where: { sameRoot($0, t) }) { return false }
            return true
        }
    }

    /// 다 읽은 뒤 정리: 표제어가 아닌 것 빼기 · 체크 칸이 글자로 붙은 것 떼기
    static func cleanEntries(_ words: [ParsedWord]) -> [ParsedWord] {
        var out: [ParsedWord] = []
        for var word in words {
            // "brief d": 체크 칸(□□)이 한 글자로 읽힌 것
            var term = word.term.replacingOccurrences(of: #"(\s+[a-zA-Z]){1,2}$"#, with: "", options: .regularExpression)
            if term.split(separator: " ").count == 1 || term == word.term { word.term = term } else { term = word.term }
            let lower = word.term.lowercased()
            let tokens = lower.split(separator: " ").map(String.init)
            let meaning = word.meaning.trimmingCharacters(in: .whitespaces)
            // 뜻이 영영풀이 표시뿐
            if meaning.range(of: #"^(영\s?영\s?풀\s?이|영풀이)$"#, options: .regularExpression) != nil { continue }
            // 관사로 시작하고 바로 앞 표제어가 든 예시 구 ("compact" 다음의 "a compact camera") — "a lot of" 같은 숙어는 그대로
            if tokens.count >= 2, ["a", "an", "the"].contains(tokens[0]), let last = out.last, !last.term.contains(" "),
               tokens.contains(last.term.lowercased()) { continue }
            // 바로 앞 표제어가 든 세 낱말 이상 (예시 구: crisis 다음의 "go through a crisis") — "look after" 같은 숙어는 그대로
            if tokens.count >= 3, let last = out.last, !last.term.contains(" "), tokens.contains(last.term.lowercased()) { continue }
            // 바로 앞 단어와 뜻이 같고 낱말 모양이 변화형 ("oversaw-overseen" 감독하다)
            if let last = out.last, last.meaning == word.meaning, lower.contains("-"), !last.term.contains("-") { continue }
            out.append(word)
        }
        return out
    }

    // MARK: - 유의어 · 반의어

    /// 유의어·반의어 표시 (기호 · 영어 약자 · 한글)
    private static let synonymMarker = #"(=|≒|≈|≃|≅|↔|⇔|⟷|⇄|⇆|←→|<->|<=>|≠|\bsyn(onyms?)?\b\.?|\bant(onyms?)?\b\.?|\bopp\.|\bsim\.|[\[\(]\s*(유|반|동의|유의|반의)\s*[\]\)]|유의어|반의어|동의어|반대어|반대말|비슷한\s?말|비슷한\s?뜻|반대\s?뜻|유의|반의|ⓢ|ⓐ|Ⓢ|Ⓐ|ⓞ|Ⓞ|[\[\(]\s*(동|비|대)\s*[\]\)]|(?<![가-힣])(유|반)(?![가-힣]))"#

    /// 줄이 유의어·반의어 표시로 시작하면 그 줄 전체가 유의어 (뒤에 한글 뜻이 있어도)
    static func isSynonymLine(_ raw: String) -> Bool {
        var t = raw.trimmingCharacters(in: .whitespaces)
        t = t.replacingOccurrences(of: #"^[\(\[]?\d{1,3}[\.\)\]]?\s*"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"^[•·\-\*▶►▷→]+\s*"#, with: "", options: .regularExpression)
        if t.range(of: "^" + synonymMarker + #"\s*[:：]?\s*[A-Za-z]"#, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        // 영어 낱말만 쉼표로 늘어놓은 줄 (glad, joyful, cheerful)
        if t.range(of: "[가-힣]", options: .regularExpression) == nil,
           t.range(of: #"^[A-Za-z][A-Za-z'’\-]*(\s*,\s*[A-Za-z][A-Za-z'’\-]*){1,}\s*$"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// "유의어", "Synonyms", "유의어 · 반의어" 같은 제목만 있는 줄
    static func isSynonymHeading(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: ":：[]()<>【】"))
        return t.range(of: #"^((유의어|반의어|동의어|반대어|반대말|비슷한\s?말|비슷한\s?뜻|반대\s?뜻|synonyms?|antonyms?|syn|ant)\s*[·/&,와과및]?\s*)+$"#,
                       options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - 줄 다듬기

    /// 한 줄을 읽기 좋게: 괄호 품사 "[명]" "(n.)" → "명" "n.", /발음/ 지우기, 유의어·반의어(= glad, ↔ sad, 유 glad)·cf. 참고 지우기
    static func normalizeRow(_ text: String) -> String {
        var t = text
        t = t.replacingOccurrences(of: #"[\(\[](명|동|형|부|전|접|대|감|자|타)[\]\)]"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?<![가-힣])(명|동|형|부|전|접|대|감)\]"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"[\(\[](n|v|vt|vi|adj|adv|ad|prep|conj|pron|int)\.?[\)\]]"#, with: "$1.",
                                   options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: #"(^|\s)/[^/\s가-힣]{1,30}/(?=\s|$)"#, with: "$1", options: .regularExpression)
        // 줄 중간의 유의어·반의어 (뒤따르는 영어 낱말들까지, 괄호째)
        t = t.replacingOccurrences(of: #"[\(\[]?\s*"# + synonymMarker + #"\s*[:：]?\s*[A-Za-z][A-Za-z ,'’\-]*[\)\]]?"#,
                                   with: " ", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: #"\s\(?cf\.\s.*$"#, with: "", options: [.regularExpression, .caseInsensitive])
        return t
    }

    private static let headerPhrases: Set<String> = [
        "word list", "wordlist", "words", "word", "vocabulary", "voca", "vocab", "check up", "checkup", "word check", "word test",
        "review test", "daily test", "self test", "quick check", "todays words", "today s words", "key words", "new words",
        "word meaning", "word meanings", "words meanings", "english korean", "meaning", "meanings", "idioms", "phrasal verbs",
        "expressions", "key expressions", "review", "exercise", "exercises", "practice"
    ]
    private static let koreanHeaders: Set<String> = [
        "단어", "뜻", "의미", "영어", "한글", "한국어", "우리말", "영단어", "품사", "발음", "예문", "번호", "체크", "확인", "단어장", "어휘", "해석"
    ]

    /// 머리말·꼬리말·쪽수 ("DAY 01", "Unit 3 Food", "Word List", "p. 34", "© 2024 …", "단어 뜻", "1일차")
    /// 뜻 없는 영어 머리말은 바로 아래가 뜻만 있는 줄이면 세로형 단어로 봄 ("Review" / "복습하다")
    static func isHeader(_ text: String, next: String?) -> Bool {
        let s = text.trimmingCharacters(in: .whitespaces)
        let lower = s.lowercased()
        func matches(_ pattern: String, _ target: String) -> Bool { target.range(of: pattern, options: .regularExpression) != nil }
        if matches(#"^(day|unit|lesson|chapter|part|step|week|stage|section|level|round|set|test|quiz|review|ch\.)\s*[-.#:]?\s*\d{1,3}(?!\d)"#, lower) { return true }
        if matches(#"^(p\.?|pp\.|page)\s*\d{1,4}$"#, lower) || matches(#"^\d{1,4}\s*/\s*\d{1,4}$"#, lower) { return true }
        if lower.contains("©") || lower.contains("www.") || lower.contains("http") || lower.contains(".com") || lower.contains("copyright") { return true }
        let hasHangul = matches("[가-힣]", s)
        let hasLatin = matches("[A-Za-z]", s)
        if hasHangul, !hasLatin {
            if matches(#"^(제\s*)?\d{1,3}\s*(일차|일째|강|과|단원|회|주차)"#, s) { return true }
            let tokens = s.split(whereSeparator: { $0 == " " || $0 == "|" || $0 == "/" }).map(String.init)
            return !tokens.isEmpty && tokens.allSatisfy { koreanHeaders.contains($0) }
        }
        if hasLatin, !hasHangul {
            let phrase = lower.replacingOccurrences(of: #"[^a-z]+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            guard headerPhrases.contains(phrase) else { return false }
            if let next, matches("[가-힣]", next), !matches("[A-Za-z]{2,}", next) { return false }
            return true
        }
        return false
    }

    /// 영어 낱말 속에 끼어든 숫자·기호를 비슷한 글자로 ("app1e" → "apple", "5mall" → "small", "c0ntinent" → "continent")
    /// 숫자만 있는 낱말(번호·쪽수)은 그대로 둠. 낱말 앞뒤에 붙은 "|"는 표 테두리라 지움
    static func fixOCRTerm(_ text: String) -> String {
        let map: [Character: Character] = ["0": "o", "1": "l", "5": "s", "|": "l", "$": "s"]
        return text.split(separator: " ", omittingEmptySubsequences: false).map { piece -> String in
            var token = Substring(piece)
            if token.contains(where: { $0.isASCII && $0.isLetter }) {
                while token.first == "|" { token = token.dropFirst() }
                while token.last == "|" { token = token.dropLast() }
            }
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
            // 한 줄에 "단어 뜻 단어 뜻"이 이어진 경우 ("happy 행복한 / happiness 행복")
            for segment in splitPairs(text) {
                let row = splitRow(segment)
                // "예문. 해석" 이 한 줄에 같이 있음
                if row.sentence {
                    afterExample = false
                    continue
                }
                let (term, meaning) = (row.term, row.meaning)
                if term.isEmpty, !meaning.isEmpty, afterExample || looksLikeKoreanSentence(meaning) {
                    afterExample = false
                    continue
                }
                afterExample = false

                switch (term.isEmpty, meaning.isEmpty) {
                case (false, false):
                    // 앞 단어는 뜻 없이 끝남 (학생이 확인 화면에서 채움)
                    if let pending = pendingTerm { result.append(ParsedWord(term: pending, meaning: "")) }
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
        }
        if let pending = pendingTerm {
            result.append(ParsedWord(term: pending, meaning: ""))
        }
        return result.map { ParsedWord(term: $0.term, meaning: cleanMeaning($0.meaning)) }
    }

    /// 낱말 종류: 한글이 든 낱말 / 영어 낱말(품사 표시·번호 제외) / 기호
    private enum TokenKind { case hangul, latin, other }
    private static func kind(_ token: String) -> TokenKind {
        if token.range(of: "[가-힣ㄱ-ㅎ]", options: .regularExpression) != nil { return .hangul }
        if token.range(of: "[A-Za-z]", options: .regularExpression) != nil, !isPOS(token) { return .latin }
        return .other
    }

    /// "apple 사과 banana 바나나" → ["apple 사과", "banana 바나나"]
    /// 뜻 뒤에 영어 낱말(4개 이하, 문장 아님) + 한글 뜻이 또 나오면 새 단어. 괄호 안이나 A·B 같은 한 글자는 뜻의 일부
    static func splitPairs(_ text: String) -> [String] {
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        var cuts: [Int] = []
        var seenLatin = false, seenHangul = false
        var depth = 0
        var i = 0
        while i < tokens.count {
            let k = kind(tokens[i])
            if k == .latin, seenLatin, seenHangul, depth == 0 {
                var j = i
                while j < tokens.count, kind(tokens[j]) == .latin { j += 1 }
                let run = tokens[i..<j]
                let wordLike = run.contains { $0.filter { $0.isASCII && $0.isLetter }.count >= 2 }
                let sentence = run.last.map { ".?!".contains($0.last ?? " ") } ?? false
                if j < tokens.count, kind(tokens[j]) == .hangul, run.count <= 4, wordLike, !sentence {
                    cuts.append(i)
                    seenHangul = false
                }
                for t in run { depth += t.filter { $0 == "(" }.count - t.filter { $0 == ")" }.count }
                i = j
                continue
            }
            if k == .latin { seenLatin = true }
            if k == .hangul, seenLatin { seenHangul = true }
            depth = max(0, depth + tokens[i].filter { $0 == "(" }.count - tokens[i].filter { $0 == ")" }.count)
            i += 1
        }
        guard !cuts.isEmpty else { return [text] }
        var segments: [String] = []
        var start = 0
        for cut in cuts + [tokens.count] {
            var piece = Array(tokens[start..<cut])
            while let last = piece.last, last == "/" || last == "|" || last == "," { piece.removeLast() }
            if !piece.isEmpty { segments.append(piece.joined(separator: " ")) }
            start = cut
        }
        return segments
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
        t = t.replacingOccurrences(of: #"(?<![A-Za-z가-힣\d])\d{1,4}(?![A-Za-z가-힣\d])"#, with: " ", options: .regularExpression)
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
        /// 페이지 순서대로 내보내려고 단어마다 나온 자리(덩어리 번호)를 함께 둠
        var found: [(order: Int, word: ParsedWord)] = []
        func push(_ word: String) {
            let hasHangul = word.range(of: "[가-힣]", options: .regularExpression) != nil
            let hasLatin = word.range(of: "[A-Za-z]", options: .regularExpression) != nil
            if isPOS(word) {
                pieces.append(.korean([word], pos: true))
            } else if hasHangul {
                if case .korean(let words, let pos)? = pieces.last {
                    pieces[pieces.count - 1] = .korean(words + [word], pos: pos)
                } else if case .lineBreak? = pieces.last, pieces.count >= 2, case .korean(let words, true) = pieces[pieces.count - 2],
                          words.count == 1 || words.last?.hasSuffix(",") == true {
                    // 품사만 있던 줄, 또는 쉼표로 끝난 뜻은 다음 줄로 이어짐 ("동 버리다," / "포기하다")
                    pieces.removeLast()
                    pieces[pieces.count - 1] = .korean(words + [word], pos: true)
                } else {
                    pieces.append(.korean([word], pos: false))
                }
            } else if hasLatin {
                if case .english(let words)? = pieces.last { pieces[pieces.count - 1] = .english(words + [word]) }
                else { pieces.append(.english([word])) }
            } else if case .korean(let words, let pos)? = pieces.last {
                // 기호(~, 쉼표, ① 등)는 앞의 뜻에 붙임
                pieces[pieces.count - 1] = .korean(words + [word], pos: pos)
            }
        }
        for text in texts {
            // 번호·체크박스가 붙은 품사 없는 줄은 목록처럼 한 줄이 단어 하나 ("□ give up 포기하다")
            if isMarkedRow(text), !stripNoise(text).split(separator: " ").contains(where: { isPOS(String($0)) }) {
                let (term, meaning) = split(text)
                let cleaned = cleanMeaning(meaning)
                if !term.isEmpty, !cleaned.isEmpty { found.append((pieces.count, ParsedWord(term: term, meaning: cleaned))) }
                pieces.append(.lineBreak)
                continue
            }
            // 뜻 번호 "1. 2." "(1)"은 지우기 전에 ①로 바꿔 둠 (뜻 사이 쉼표가 됨)
            let numbered = text.replacingOccurrences(of: #"(\s)(\(\d{1,2}\)|\d{1,2}[.)])(?=\s*[가-힣])"#, with: "$1①", options: .regularExpression)
            for raw in stripNoise(numbered).components(separatedBy: " ") where !raw.isEmpty {
                if raw == "/" { pieces.append(.slash); continue }
                push(raw)
            }
            pieces.append(.lineBreak)
        }

        // 2) 품사 덩어리마다 표제어 찾기
        var used = Set<Int>()
        var lastOwner: (index: Int, piece: Int)?
        for (i, piece) in pieces.enumerated() {
            guard case .korean(let words, true) = piece else { continue }
            let meaning = cleanMeaning(words.joined(separator: " "))
            // 바로 앞이 같은 단어의 다른 품사면 이어 붙임 ("instant 형 즉각적인 명 순간")
            if let owner = lastOwner, owner.piece == i - 1 {
                found[owner.index].word.meaning += ", " + meaning
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
            found.append((owner, ParsedWord(term: term, meaning: meaning)))
            lastOwner = (found.count - 1, i)
        }
        // 3) 품사 표시 없이 "영어 한 낱말 + 뜻"만 있는 줄도 단어로 (예시 구·예문은 여러 낱말이라 빠짐)
        //    표제어만 있는 줄 바로 아래 줄이 뜻뿐이면 그것도 ("apple [ǽpl]" / "사과")
        func isBreak(_ index: Int) -> Bool {
            guard index >= 0, index < pieces.count else { return true }
            if case .lineBreak = pieces[index] { return true }
            return false
        }
        for (i, piece) in pieces.enumerated() where !used.contains(i) {
            guard case .english(let words) = piece, words.count == 1 else { continue }
            var meaningWords: [String]?
            if i + 1 < pieces.count, case .korean(let after, false) = pieces[i + 1] {
                meaningWords = after
            } else if isBreak(i - 1), isBreak(i + 1), i + 2 < pieces.count, case .korean(let below, false) = pieces[i + 2], isBreak(i + 3) {
                meaningWords = below
            }
            guard let meaningWords else { continue }
            let meaning = cleanMeaning(meaningWords.joined(separator: " "))
            let term = cleanTerm(words[0])
            if !term.isEmpty, !meaning.isEmpty, !looksLikeKoreanSentence(meaning) { found.append((i, ParsedWord(term: term, meaning: meaning))) }
        }
        return found.enumerated().sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }.map(\.element.word)
    }

    /// 줄 앞에 번호나 체크박스가 있는지 ("001 ", "1. ", "□ ")
    private static func isMarkedRow(_ text: String) -> Bool {
        text.range(of: #"^\s*([□■☐☑✓✔•·\*]|\d{1,4}([.)]|\s))"#, options: .regularExpression) != nil
    }

    /// 뜻 정리: 뜻 번호(①, 1.)는 쉼표로, 발음·번호 지우기, 예문 해석 같은 문장 조각 빼기, 끝의 영어 낱말 떼기
    static func cleanMeaning(_ raw: String) -> String {
        var t = normalizeEnumeration(raw).replacingOccurrences(of: #"[;；]"#, with: ",", options: .regularExpression)
        t = stripExample(from: stripNoise(t))
        t = t.replacingOccurrences(of: #"\s+[A-Za-z][A-Za-z\-']*\s*$"#, with: "", options: .regularExpression)
        let hasKorean = t.range(of: "[가-힣]", options: .regularExpression) != nil
        let parts = t.components(separatedBy: ",").map { part -> String in
            // 한글 뜻 뒤에 붙은 영어 낱말 (옆에 적힌 유의어: "행복한 glad") 떼기
            part.replacingOccurrences(of: #"(?<=[가-힣\)])\s+[A-Za-z][A-Za-z'’\-]*(\s+[A-Za-z][A-Za-z'’\-]*)?\s*$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }
            .filter { !$0.isEmpty && !looksLikeKoreanSentence($0) && $0.range(of: "[가-힣A-Za-z]", options: .regularExpression) != nil }
            // 뜻에 한글이 있으면, 영어만 있는 쉼표 칸은 유의어 (품사 표시 n. 같은 건 남김)
            .filter { !hasKorean || $0.range(of: "[가-힣]", options: .regularExpression) != nil || isPOS($0) }
        t = stripPartOfSpeech(parts.joined(separator: ", "))
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: CharacterSet(charactersIn: " ,/;:.|=-："))
    }

    /// 뜻에 섞인 품사 표시 지우기: "명) 사과", "[동] 달리다", "가장 큰 명", "부사 빨리", "n. 사과"
    /// 괄호 없는 한 글자(명·부…)는 같은 칸에 다른 말이 있을 때만 지움 ("부, 재산"의 '부'는 뜻일 수 있음)
    static func stripPartOfSpeech(_ meaning: String) -> String {
        let fullWords = #"(명사|동사|형용사|부사|전치사|접속사|대명사|감탄사|조동사|관사|자동사|타동사)"#
        let short = #"(명|동|형|부|전|접|대|감|자|타|자동|타동)"#
        let parts = meaning.components(separatedBy: ",").map { raw -> String in
            var part = raw
            // 괄호·점이 붙은 품사는 어디 있든 지움: (명) [동] <형> 명) 부. 명:
            part = part.replacingOccurrences(of: "[\\(\\[<{]\\s*(\(fullWords)|\(short))\\s*([\\)\\]>}]|(?=\\s))", with: " ", options: .regularExpression)
            part = part.replacingOccurrences(of: "(?<![가-힣])(\(fullWords)|\(short))[\\)\\]>.:](?![가-힣])|(?<![가-힣])(\(fullWords)|\(short))[\\)\\]>](?=[가-힣])", with: " ", options: .regularExpression)
            // 영어 품사 표시 n. v. adj. …
            part = part.replacingOccurrences(of: #"(?i)(?<![A-Za-z])\(?(n|v|vt|vi|a|adj|adv|ad|prep|conj|pron|int)\.\)?(?![A-Za-z])"#, with: " ", options: .regularExpression)
            // 품사 이름 낱말 (명사·부사 …)이 따로 떨어져 있으면
            var tokens = part.split(separator: " ").map(String.init)
            if tokens.count > 1 { tokens.removeAll { $0.range(of: "^\(fullWords)$", options: .regularExpression) != nil } }
            // 괄호 없는 한 글자 품사: 다른 말과 같이 있을 때만
            if tokens.count > 1 {
                tokens.removeAll { $0.range(of: "^\(short)$", options: .regularExpression) != nil }
            }
            return tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// "사과 ② 능금", "명 ① 은행 ② 둑", "달리다 2. 운영하다" → 뜻 번호를 쉼표로 (맨 앞 번호는 지움)
    private static func normalizeEnumeration(_ text: String) -> String {
        let spaced = text.replacingOccurrences(of: "([①-⑳])", with: " $1 ", options: .regularExpression)
        var out: [String] = []
        var hasContent = false, needComma = false
        for token in spaced.split(whereSeparator: \.isWhitespace).map(String.init) {
            if token.range(of: #"^([①-⑳]|\d{1,2}[.)]|\(\d{1,2}\))$"#, options: .regularExpression) != nil {
                if hasContent { needComma = true }
                continue
            }
            if needComma, let last = out.last {
                if !last.hasSuffix(",") { out[out.count - 1] = last + "," }
                needComma = false
            }
            out.append(token)
            if !isPOS(token), token.range(of: "[가-힣A-Za-z]", options: .regularExpression) != nil { hasContent = true }
        }
        return out.joined(separator: " ")
    }

    /// "1. apple n. 사과, 능금" → ("apple", "n. 사과, 능금")
    static func split(_ raw: String) -> (term: String, meaning: String) {
        let row = splitRow(raw)
        return row.sentence ? ("", row.meaning) : (row.term, row.meaning)
    }

    /// 한 줄을 단어/뜻으로. sentence = 영어 예문 + 해석이 한 줄에 있음
    private static func splitRow(_ raw: String) -> (term: String, meaning: String, sentence: Bool) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 번호, 체크박스, 표 테두리 제거 ("5mall" 같은 낱말 속 숫자는 남김)
        s = s.replacingOccurrences(of: #"^[\(\[]?\d{1,4}(?:[\.\)\]:]\s*|\s+)"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^[□■☐☑✓✔•·\-\*\|–—]+\s*"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^\d{1,4}[\.\)]\s*"#, with: "", options: .regularExpression)
        // 번호 숫자를 비슷한 글자로 읽은 것: "S. efficient"(5), "b. fragile"(6), "y. journey"(9), "1O. knowledge"(10)
        s = s.replacingOccurrences(of: #"^(?:[SsbGgqyZzlIOoB]|\d[OolISsZzB]|[OolISsZzB]\d)[\.\)]\s+(?=[A-Za-z]{2})"#, with: "", options: .regularExpression)

        var tokens = s.split(whereSeparator: \.isWhitespace).map(String.init)
        // 띄어쓰기 없이 붙은 "apple사과" → "apple" "사과" (소문자가 든 두 글자 이상 영어 + 한글일 때만, "A와" "TV를"은 그대로)
        if let glued = tokens.firstIndex(where: { kind($0) == .hangul }),
           let match = tokens[glued].firstMatch(of: #/^([A-Za-z][A-Za-z'’\-]+)([가-힣ㄱ-ㅎ~(].*)$/#),
           match.1.contains(where: \.isLowercase) {
            tokens.replaceSubrange(glued...glued, with: [String(match.1), String(match.2)])
        }
        guard let first = tokens.firstIndex(where: { kind($0) == .hangul }) else {
            return (cleanTerm(stripTermNoise(s)), "", false)
        }

        // 한글이 먼저 나오고 끝에 영어가 있음 ("사과 - apple")
        if first == 0, let lastHangul = tokens.lastIndex(where: { kind($0) == .hangul }) {
            let tail = tokens[(lastHangul + 1)...]
            let head = tokens[...lastHangul]
            if tail.contains(where: { kind($0) == .latin }), tail.count <= 6, !head.contains(where: { kind($0) == .latin }) {
                let term = cleanTerm(stripTermNoise(tail.joined(separator: " ")))
                if !term.isEmpty { return (term, stripExample(from: head.joined(separator: " ")), false) }
            }
        }

        var meaningTokens = Array(tokens[first...])
        tokens = Array(tokens[..<first])
        // 단어 끝의 기호: "~"·"(" 는 뜻의 시작 ("be good at ~을", "employ (사람을"), 나머지(-, :, |, ①)는 버림
        while let last = tokens.last, kind(last) != .latin, !isPOS(last) {
            tokens.removeLast()
            if last.contains("~") || last.contains("(") { meaningTokens.insert(last, at: 0) }
        }
        var termPart = tokens.joined(separator: " ")
        var meaningPart = meaningTokens.joined(separator: " ")

        // 단어 뒤에 붙은 품사 표시는 뜻 쪽으로 이동 (n. v. adj. ...)
        if let posRange = termPart.range(
            of: #"(^|\s)((n|v|a)\.|(vt|vi|ad|adj|adv|prep|conj|pron|int|phr)\.?)\s*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            let pos = termPart[posRange].trimmingCharacters(in: .whitespaces)
            termPart = String(termPart[..<posRange.lowerBound])
            meaningPart = pos + " " + meaningPart
        }
        termPart = stripTermNoise(termPart)

        // 영어 예문 + 해석이 한 줄에 ("She is kind to everyone. 그녀는 …")
        let trimmedTerm = termPart.trimmingCharacters(in: .whitespaces)
        if trimmedTerm.split(separator: " ").count >= 3, let last = trimmedTerm.last, ".?!\"”".contains(last) {
            return ("", meaningPart, true)
        }

        // 뜻 뒤에 붙은 예문 떼기 ("용감한 She was brave." / "용감한 예) …" / "용감한 ex. …")
        meaningPart = stripExample(from: meaningPart)
        meaningPart = meaningPart.trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleanTerm(termPart), meaningPart, false)
    }

    /// 단어 쪽의 [발음]·(= 다른 철자) 같은 한글 없는 괄호 지우기
    private static func stripTermNoise(_ text: String) -> String {
        text.replacingOccurrences(of: #"[\[\(][^\]\)가-힣]{1,30}[\]\)]"#, with: " ", options: .regularExpression)
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
        // "I like apples", "She runs fast" 처럼 대문자 주어로 시작하는 세 낱말 이상
        if ["I", "You", "He", "She", "We", "They", "It"].contains(first) { return true }
        let function: Set<String> = ["i", "you", "he", "she", "it", "we", "they", "this", "that", "there", "my", "his", "her", "our", "their",
                                     "is", "are", "was", "were", "am", "will", "can", "do", "does", "did", "have", "has", "had", "the"]
        let hasFunction = words.dropFirst().contains { function.contains($0.lowercased()) } || function.contains(first.lowercased())
        return first.first?.isUppercase == true && hasFunction && words.count >= 4
    }

    /// 한글 문장인지 (예문 해석): 마침표로 끝나거나, 띄어쓰기가 많고 주어(~은/는/이/가)가 있으며 "~다/~요"로 끝남
    /// ("포기하다", "(해야 할 일을) 미루다", "A와 B 둘 다" 같은 뜻은 아님)
    static func looksLikeKoreanSentence(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard s.count >= 8, !s.contains(",") else { return false }
        if s.hasSuffix(".") || s.hasSuffix("?") || s.hasSuffix("!") { return true }
        let core = s.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        let words = core.split(separator: " ")
        guard words.count >= 4, let last = words.last, last.hasSuffix("다") || last.hasSuffix("요") else { return false }
        return words.dropLast().contains { word in ["은", "는", "이", "가"].contains { word.hasSuffix($0) } }
    }

    /// 뜻 뒤에 이어 붙은 예문 잘라내기
    static func stripExample(from meaning: String) -> String {
        var m = meaning
        // 예문 표시가 나오면 거기서 자름
        for marker in [#"\s(e\.\s?g\.?|eg\.|ex[.):]|예\)|예:|예문|ⓔ|▶|►|→|cf\.)"#] {
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
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-~'’")))

        // 영어 글자가 두 개 이상 있어야 하고 (쪽수 "p." 같은 한 글자 제외), 예문처럼 긴 문장은 제외
        guard term.filter({ $0.isASCII && $0.isLetter }).count >= 2 else { return "" }
        guard term.range(of: "[가-힣]", options: .regularExpression) == nil else { return "" }
        let wordCount = term.split(separator: " ").count
        guard wordCount <= 6, term.count <= 50 else { return "" }
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
