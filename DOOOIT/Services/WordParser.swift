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

        for row in rows {
            let text = row
                .sorted { $0.box.minX < $1.box.minX }
                .map(\.text)
                .joined(separator: " ")
            let (term, meaning) = split(text)

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

        // 괄호로 시작하는 뜻 앞부분 정리
        meaningPart = meaningPart.trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleanTerm(termPart), meaningPart)
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
