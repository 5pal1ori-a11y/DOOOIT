import Foundation

struct ParsedWord: Identifiable, Hashable {
    var id = UUID()
    var term: String
    var meaning: String
}

/// OCR 결과를 "영어 단어 - 한글 뜻" 쌍으로 변환
enum WordParser {
    static func parse(_ lines: [OCRLine]) -> [ParsedWord] {
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

        // 2) 행마다 단어/뜻 분리
        var result: [ParsedWord] = []
        var pendingTerm: String?
        /// 바로 앞 줄이 예문이었으면, 다음 한글 줄은 그 예문의 해석이라 뜻에 붙이지 않음
        var afterExample = false

        for row in rows {
            let text = row
                .sorted { $0.box.minX < $1.box.minX }
                .map(\.text)
                .joined(separator: " ")
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

        // 3) 중복 제거
        var seen = Set<String>()
        return result.filter { seen.insert($0.term.lowercased()).inserted }
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

    private static func cleanTerm(_ raw: String) -> String {
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
