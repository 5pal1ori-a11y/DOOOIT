import Foundation

/// 오답노트 풀이 탭: AI가 문제를 읽고 직접 풀어 답과 풀이를 냄
/// 1) 수학은 풀이 엔진이 직접 풀기 (계산으로 확인한 답)
/// 2) 엔진이 못 풀면 · 다른 과목은 두잇 1·2 모델이 풀기 (추측이라 확인해 보라고 표시)
enum DoitAutoSolve {
    static let engineSource = "engine"
    static let modelSource = "model"

    /// 풀이 엔진으로 풀기 (객관식이면 엔진 답과 같은 선지 번호로)
    /// 사진 글을 여러 모양으로 고쳐 풀어 보고 가장 그럴듯한 답을 고름:
    /// 그대로 · 선지 뺀 본문 · 문제 번호 뺀 글 ("3. 56÷□=8"이 "3.56÷□=8"로 붙어 읽힌 것도)
    static func engine(text: String, choices: [String], isChoice: Bool, body: String? = nil) -> WrittenSolution? {
        let full = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let best = bestSolved(text: full, choices: choices, isChoice: isChoice, body: body) else { return nil }
        var solution = DoitSolutionWriter.write(best.solved)
        // 선지와 안 맞은 값은 선지 번호로 오해하지 않게 ("4" → "계산한 값: 4")
        solution.finalAnswer = isChoice && !best.matched ? "계산한 값: " + best.key : best.key
        solution.source = engineSource
        solution.problem = full
        return solution
    }

    /// 여러 모양으로 풀어 보고 가장 그럴듯한 풀이 (객관식이면 key는 선지 번호) — AI와 함께 풀기에서도 씀
    static func bestSolved(text: String, choices: [String], isChoice: Bool, body: String? = nil) -> (solved: MathSolver.Solved, key: String, matched: Bool)? {
        let full = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !full.isEmpty else { return nil }
        var best: (solved: MathSolver.Solved, key: String, matched: Bool, score: Int)?
        for candidate in candidates(full: full, body: body, choices: choices) {
            // 고쳐 쓴 글(식만 뗀 것 등)에는 물음이 빠져 있을 수 있어서, 물은 값인지는 원래 글로 다시 확인
            guard let solved = MathSolver.solve(candidate).flatMap({ DoitMathAsked.focus($0, full) }) else { continue }
            var key = solved.answer
            var matched = false
            if isChoice, let n = choiceIndex(for: key, choices: choices) {
                key = "\(n)"; matched = true
            }
            let score = niceness(key, matched: matched, isChoice: isChoice)
            if best == nil || score > best!.score { best = (solved, key, matched, score) }
        }
        return best.map { ($0.solved, $0.key, $0.matched) }
    }

    /// 엔진 답이 몇 번 선지인지
    /// 1) 엔진이 번호를 직접 고른 답 ("③ 5", "3번")만 번호로 읽음: 값 "5"를 ⑤번으로 읽으면 안 돼요
    /// 2) 선지 내용과 같은 값·식 ("x = 1에서 극댓값 5"의 5, "x = 3"의 3도)
    static func choiceIndex(for key: String, choices: [String]) -> Int? {
        let t = key.trimmingCharacters(in: .whitespaces)
        let circled: [Character: Int] = ["①": 1, "②": 2, "③": 3, "④": 4, "⑤": 5]
        if let first = t.first, let n = circled[first], t.count == 1 || t.dropFirst().first?.isWhitespace == true {
            return (1...choices.count).contains(n) ? n : nil
        }
        if let m = t.firstMatch(of: #/^([1-9])\s*번$/#), let n = Int(String(m.1)) { return (1...choices.count).contains(n) ? n : nil }
        func unique(_ test: (String) -> Bool) -> Int? {
            let hits = choices.indices.filter { test(choices[$0]) }
            return hits.count == 1 ? hits[0] + 1 : nil
        }
        for form in DoitMathExact.answerForms(t) {
            if let n = unique({ DoitGrader.normalizeText($0) == DoitGrader.normalizeText(form) }) { return n }
            if let n = unique({ DoitGrader.equivalentMath($0, form) == true }) { return n }
            if let n = unique({ DoitMathExact.sameValue($0, form) == true }) { return n }
            if let value = answerValue(of: form),
               let n = unique({ answerValue(of: $0).map { abs($0 - value) < 1e-9 } ?? false }) { return n }
        }
        return nil
    }

    /// 풀어 볼 글들 (앞에 있을수록 먼저: 점수가 같으면 앞의 것)
    /// 번호 뺀 글 → 그대로 → 식만 → 소수처럼 붙은 번호를 뺀 글 ("0.3 × 0.4"를 "3 × 0.4"로 읽지 않게 맨 뒤)
    static func candidates(full: String, body: String?, choices: [String]) -> [String] {
        let main = (body?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        let bases = [full, main].compactMap { $0 }
        let withChoices: (String) -> [String] = { text in
            guard text != full, !choices.isEmpty else { return [text] }
            // 본문에 선지를 다시 붙임 (선지로 고르는 문제: "다음 중 소수인 것은?")
            return [text, text + "\n" + choices.enumerated().map { "\(DoitGuidedSolve.circled($0.offset + 1)) \($0.element)" }.joined(separator: " ")]
        }
        var stripped: [String] = [], original: [String] = [], expressions: [String] = [], glued: [String] = []
        for base in bases {
            let s = stripNumber(base)
            stripped += s.spaced.flatMap(withChoices)
            original += withChoices(base)
            for text in s.spaced + [base] {
                if let e = leadingExpression(text) { expressions.append(e) }
            }
            glued += s.glued.flatMap(withChoices)
        }
        // "x = 2일 때, 식 3x − 1의 값" → "3×(2) − 1의 값은?" (방정식 x = 2를 푸는 게 아니라 넣어서 계산)
        let substituted = bases.flatMap { stripNumber($0).spaced + [$0] }.compactMap(substitute)
        var seen = Set<String>()
        return (substituted + stripped + original + expressions + glued).filter { seen.insert($0).inserted }
    }

    /// "x = 2일 때, (식) 3x − 1의 값" → "3×(2) − 1의 값은?"
    static func substitute(_ text: String) -> String? {
        // 값: 수 · 분수 · 1 + √2 · 2 − √3 · √5
        let number = #"−?-?[0-9]+(?:[./][0-9]+)?"#
        let surd = #"[0-9]*\s*√\s*[0-9]+"#
        let valuePattern = #"(?:\#(number)(?:\s*[+\-−]\s*\#(surd))?|−?-?\#(surd)(?:\s*[+\-−]\s*[0-9]+)?)"#
        let pattern = "([a-z])\\s*=\\s*(\(valuePattern))\\s*일\\s*때\\s*,?\\s*(?:식\\s*)?(.+?)\\s*의\\s*값"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for m in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let vr = Range(m.range(at: 1), in: text), let nr = Range(m.range(at: 2), in: text), let er = Range(m.range(at: 3), in: text) else { continue }
            // "x + 1/x = 4일 때", "3^x = 81일 때", "log₂ x = 3일 때"의 x = 4는 x의 값이 아님: 문자 앞이 글 처음·한글·쉼표일 때만
            let before = text[..<vr.lowerBound].trimmingCharacters(in: .whitespaces)
            if let last = before.last, !(DoitSubjectNote.isHangul(last) || ",，:".contains(last)) { continue }
            let variable = Character(String(text[vr]))
            let value = String(text[nr]).replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: " ", with: "")
            let expression = String(text[er])
            // 묻는 식이 그 문자 하나뿐이면 ("x의 값") 넣어서 계산할 게 없어요
            guard expression.contains(variable), expression.trimmingCharacters(in: .whitespaces) != String(variable),
                  !expression.contains(where: { DoitSubjectNote.isHangul($0) }) else { continue }
            return substituted(expression, variable: variable, value: value)
        }
        return nil
    }

    private static func substituted(_ expression: String, variable: Character, value: String) -> String {
        var out = ""
        var previous: Character?
        for c in expression {
            if c == variable {
                if let p = previous, p.isNumber || p == ")" { out += "×" }
                out += "(\(value))"
            } else {
                out.append(c)
            }
            previous = c
        }
        return out + "의 값은?"
    }

    /// 맨 앞 문제 번호 빼기
    /// - spaced: "12. " · "07 " · "1^1. " · "16) " · "8.√12"
    /// - glued: 번호 뒤 띄어쓰기가 빠져 소수처럼 읽힌 "3.56÷□=8" → "56÷□=8" (점수로 고름)
    static func stripNumber(_ text: String) -> (spaced: [String], glued: [String]) {
        var spaced: [String] = []
        let patterns = [#"^\s*\d{1,2}\^?\d?\s*[.)．]\s+"#, #"^\s*0\d\s+"#, #"^\s*\d{1,2}\s*[.)．](?=[가-힣(√\[])"#]
        for pattern in patterns {
            let s = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            if s != text, !s.isEmpty, !spaced.contains(s) { spaced.append(s) }
        }
        let g = text.replacingOccurrences(of: #"^\s*\d{1,2}\.(?=\d)"#, with: "", options: .regularExpression)
        return (spaced, g != text && !g.isEmpty ? [g] : [])
    }

    /// 첫 줄 앞쪽의 식만 ("2^5 × 2^3을 2의 거듭제곱으로" → "2^5 × 2^3"): 뒤 한글 속 숫자가 식에 붙지 않게
    static func leadingExpression(_ text: String) -> String? {
        let first = text.components(separatedBy: .newlines).first ?? text
        guard let hangul = first.firstIndex(where: { DoitSubjectNote.isHangul($0) }) else { return nil }
        let expression = String(first[..<hangul]).trimmingCharacters(in: .whitespaces)
        let mathy = expression.filter { $0.isNumber || "+-−×÷*/^√()=<>≤≥□xyab".contains($0) }
        guard expression.count >= 3, mathy.count * 10 >= expression.filter({ !$0.isWhitespace }).count * 8,
              expression.contains(where: { "+-−×÷*/^√=".contains($0) }) else { return nil }
        let rest = first[hangul...]
        // 지시에 맞춰 붙임 ("…의 값은?"으로 계산, 전개·인수분해·간단히는 그 말을 그대로)
        for verb in ["전개", "인수분해", "간단히"] where rest.contains(verb) { return expression + " 을 " + verb + "하시오" }
        if expression.contains("=") || expression.contains("<") || expression.contains(">") { return expression }
        return expression + "의 값은?"
    }

    /// 답이 그럴듯한지: 선지와 맞음 > 정수·간단한 분수 > 긴 소수 > 아주 크거나 작은 수(잘못 읽은 글)
    private static func niceness(_ answer: String, matched: Bool, isChoice: Bool) -> Int {
        var score = 0
        if isChoice { score += matched ? 10 : -5 }
        if answer.contains("e+") || answer.contains("e-") { score -= 8 }
        if let value = answerValue(of: answer) {
            if value == value.rounded(), abs(value) < 1e6 { score += 2 }
            let digits = answer.filter(\.isNumber).count
            if digits > 6 { score -= 3 }
        }
        if answer.contains("해가 없") { score -= 2 }
        return score
    }

    /// "□ = 7", "x = 2", "7" → 7 (값 하나일 때만)
    private static func answerValue(of answer: String) -> Double? {
        var t = answer
        if let eq = t.lastIndex(of: "=") { t = String(t[t.index(after: eq)...]) }
        t = t.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: " ", with: "")
        // 끝에 붙은 어림값·설명 ("257/16 (≈ 16.06)")만 떼요: "2(5x² + 4x + 8)"의 2를 값으로 읽으면 안 돼요
        if let r = answer.range(of: #"\s+\([^()]*\)\s*$"#, options: .regularExpression) {
            t = String(answer[..<r.lowerBound])
            if let eq = t.lastIndex(of: "=") { t = String(t[t.index(after: eq)...]) }
            t = t.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: " ", with: "")
        }
        if let v = Double(t) { return v }
        let parts = t.split(separator: "/")
        if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]), b != 0 { return a / b }
        return nil
    }

    /// 모델에게 문제 풀게 하기 (첫 줄 "정답: …", 다음 줄부터 짧은 풀이)
    static func modelPrompt(problem: String, choices: [String], subjectName: String, problemType: ProblemType?) -> String {
        var parts: [String] = ["[과목] \(subjectName)"]
        if let problemType {
            parts.append("[문제 유형] \(problemType.name): \(problemType.asks) 푸는 법: \(problemType.steps.joined(separator: " → "))")
        }
        parts.append("[문제]\n" + problem.trimmingCharacters(in: .whitespacesAndNewlines))
        if !choices.isEmpty {
            parts.append("[선택지]\n" + choices.enumerated().map { "\($0.offset + 1)) \($0.element)" }.joined(separator: "\n"))
        }
        parts.append("이 문제를 풀어 주세요. 먼저 풀이를 2~4줄로 짧게 쓰고, 마지막 줄에 '정답: ' 뒤에 답만" + (choices.isEmpty ? "" : " (선택지 번호)")
                     + " 써 주세요. 문제에 없는 내용은 지어내지 마세요.")
        return parts.joined(separator: "\n\n")
    }

    /// 모델 답 읽기: "정답: 3" / "**정답:** ③" / "답은 광합성이에요" → 풀이. 정답이 없거나 선지 번호가 이상하면 nil
    static func parseModel(_ raw: String, problem: String, choices: [String]) -> WrittenSolution? {
        let lines = raw.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "*#>")).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }
        // 정답 줄은 보통 마지막 (앞에 있어도 됨)
        var answerIndex = lines.lastIndex(where: { answerValue($0) != nil })
        var answer = answerIndex.flatMap { answerValue(lines[$0]) }
        // 정답 줄이 없으면 객관식은 끝 두 줄에서 "③" · "3번"을 찾음
        if answer == nil, !choices.isEmpty {
            for (i, line) in lines.enumerated().reversed().prefix(2) {
                if let n = choiceMention(line), (1...choices.count).contains(n) { answer = "\(n)"; answerIndex = i; break }
            }
        }
        guard var value = answer, let index = answerIndex else { return nil }
        if !choices.isEmpty {
            guard let n = DoitGrader.choiceNumber(value, choices: choices) ?? leadingNumber(value) ?? choiceMention(value),
                  (1...choices.count).contains(n) else { return nil }
            value = "\(n)"
        }
        guard !value.isEmpty, value.count <= 80 else { return nil }
        let steps = lines.enumerated()
            .filter { $0.offset != index && answerValue($0.element) == nil }
            .map(\.element)
            .prefix(5)
            .map { SolutionStep(hint: "", work: $0.replacingOccurrences(of: #"^(\d+[.)]|[-•·]|풀이\s*:)\s*"#, with: "", options: .regularExpression)) }
            .filter { !$0.work.isEmpty }
        var solution = WrittenSolution(concept: "", steps: Array(steps), finalAnswer: value)
        solution.source = modelSource
        solution.problem = problem.trimmingCharacters(in: .whitespacesAndNewlines)
        return solution
    }

    /// "정답: x" · "답: x" · "정답은 x" · "Answer: x" → x
    private static func answerValue(_ line: String) -> String? {
        let pattern = #"^(?:따라서\s*)?(정답|답|Answer|answer)\s*(:|：|은|는|=)\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 3), in: line) else { return nil }
        var value = String(line[range]).trimmingCharacters(in: .whitespaces)
        for suffix in ["입니다.", "입니다", "이에요.", "이에요", "예요.", "예요", "이다.", "."] where value.hasSuffix(suffix) {
            value = String(value.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        return value.isEmpty ? nil : value
    }

    /// 글 속 선지 번호: "③" · "3번"
    private static func choiceMention(_ text: String) -> Int? {
        let circled: [Character: Int] = ["①": 1, "②": 2, "③": 3, "④": 4, "⑤": 5]
        if let n = text.compactMap({ circled[$0] }).first { return n }
        guard let regex = try? NSRegularExpression(pattern: #"([1-9])\s*번"#),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return Int(text[r])
    }

    /// "3번", "3)" 같은 앞 숫자
    private static func leadingNumber(_ text: String) -> Int? {
        let digits = text.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// 저장된 풀이를 다시 써도 되는지 (문제 글이 바뀌었거나 예전 방식 풀이면 다시 풂)
    static func isCurrent(_ solution: WrittenSolution?, problem: String) -> Bool {
        guard let solution, solution.source != nil, let saved = solution.problem else { return false }
        return saved == problem.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 두잇 AI 대화: 사진 속 문제 풀기

    /// 풀어 달라는 말인지 ("풀어줘", "답 알려줘", "이거 몇 번이야?", "어떻게 풀어?")
    /// 저장·단어·메모·유형·과목을 묻는 말은 아님
    static func asksToSolve(_ question: String) -> Bool {
        let q = question.replacingOccurrences(of: " ", with: "")
        if ["저장", "노트에", "단어", "메모", "유형", "과목", "읽어", "분석"].contains(where: { q.contains($0) }) { return false }
        return ["풀어", "풀이", "풀자", "푸는", "정답", "답알려", "답이뭐", "답뭐", "답은", "몇번", "계산", "어떻게풀", "구해", "해설", "알려줘", "모르겠"].contains { q.contains($0) }
            || q == "답" || q == "답?" || q == "이거" || q == "이거?"
    }

    /// 사진 글이 문제처럼 보이는지 (선지 · 물음표 · "구하시오"·"고르시오" 같은 지시 · 빈칸)
    static func looksLikeProblem(_ text: String, scan: ProblemScan) -> Bool {
        if scan.choices.count >= 2 { return true }
        let t = text.replacingOccurrences(of: " ", with: "")
        if t.contains("□") || t.contains("?") || t.contains("？") { return true }
        return ["구하시오", "고르시오", "쓰시오", "나타내시오", "계산하시오", "전개하시오", "인수분해하시오", "간단히하시오",
                "것은", "무엇인가", "얼마인가", "설명하시오", "서술하시오"].contains { t.contains($0) }
    }

    /// 대화에 보여 줄 풀이: 정답 → 핵심 개념 → 단계 (모델이 푼 답은 확인 안내)
    static func chatText(_ solution: WrittenSolution, choices: [String], typeName: String? = nil) -> String {
        let fromModel = solution.source == modelSource
        var lines: [String] = []
        if let typeName { lines.append("📌 \(typeName) 문제예요") }
        let answer = DoitSubjectNote.describe(solution.finalAnswer, choices: choices)
        lines.append("**정답\(fromModel ? " (AI 추측)" : ""): \(answer)**")
        if !solution.concept.isEmpty { lines.append("💡 " + solution.concept) }
        for (i, step) in solution.steps.prefix(8).enumerated() {
            let hint = step.hint.trimmingCharacters(in: .whitespaces)
            let work = step.work.trimmingCharacters(in: .whitespaces)
            if hint.isEmpty { lines.append("\(i + 1). \(work)") }
            else { lines.append("\(i + 1). \(hint)" + (work.isEmpty ? "" : " → \(work)")) }
        }
        if fromModel { lines.append("AI가 추측한 답이에요. 꼭 확인해 보세요.") }
        else if solution.finalAnswer.hasPrefix("계산한 값") { lines.append("선지에서 같은 답을 못 찾았어요. 사진 글이 맞게 읽혔는지 확인해 보세요.") }
        return lines.joined(separator: "\n")
    }
}
