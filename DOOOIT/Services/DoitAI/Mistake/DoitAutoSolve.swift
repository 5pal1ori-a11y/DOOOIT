import Foundation

/// 오답노트 풀이 탭: AI가 문제를 읽고 직접 풀어 답과 풀이를 냄
/// 1) 수학은 풀이 엔진이 직접 풀기 (계산으로 확인한 답)
/// 2) 엔진이 못 풀면 · 다른 과목은 두잇 1·2 모델이 풀기 (추측이라 확인해 보라고 표시)
enum DoitAutoSolve {
    static let engineSource = "engine"
    static let modelSource = "model"

    /// 풀이 엔진으로 풀기 (객관식이면 엔진 답과 같은 선지 번호로)
    static func engine(text: String, choices: [String], isChoice: Bool) -> WrittenSolution? {
        let full = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !full.isEmpty, let solved = MathSolver.solve(full) else { return nil }
        var solution = DoitSolutionWriter.write(solved)
        var key = solved.answer
        if isChoice, DoitGrader.choiceNumber(key, choices: choices) == nil,
           let index = choices.firstIndex(where: { DoitGrader.equivalentMath($0, key) == true }) {
            key = "\(index + 1)"
        }
        solution.finalAnswer = key
        solution.source = engineSource
        solution.problem = full
        return solution
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
        parts.append("이 문제를 풀어 주세요. 첫 줄은 '정답: ' 뒤에 답만" + (choices.isEmpty ? "" : " (선택지 번호)")
                     + " 쓰고, 다음 줄부터 풀이를 2~4줄로 짧게 써 주세요. 문제에 없는 내용은 지어내지 마세요.")
        return parts.joined(separator: "\n\n")
    }

    /// 모델 답 읽기: "정답: 3" / "정답: ③" / "답: 광합성" → 풀이. 정답 줄이 없거나 선지 번호가 이상하면 nil
    static func parseModel(_ raw: String, problem: String, choices: [String]) -> WrittenSolution? {
        let lines = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "*#")) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let index = lines.firstIndex(where: { answerValue($0) != nil }), var answer = answerValue(lines[index]) else { return nil }
        if !choices.isEmpty {
            guard let n = DoitGrader.choiceNumber(answer, choices: choices) ?? leadingNumber(answer),
                  (1...choices.count).contains(n) else { return nil }
            answer = "\(n)"
        }
        let steps = lines[(index + 1)...]
            .filter { answerValue($0) == nil }
            .prefix(5)
            .map { line in
                SolutionStep(hint: "", work: line.replacingOccurrences(of: #"^(\d+[.)]|[-•·])\s*"#, with: "", options: .regularExpression))
            }
        guard !answer.isEmpty, answer.count <= 80 else { return nil }
        var solution = WrittenSolution(concept: "", steps: Array(steps), finalAnswer: answer)
        solution.source = modelSource
        solution.problem = problem.trimmingCharacters(in: .whitespacesAndNewlines)
        return solution
    }

    /// "정답: x" · "답: x" · "정답은 x" → x
    private static func answerValue(_ line: String) -> String? {
        let pattern = #"^(정답|답)\s*(:|：|은|는|=)\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 3), in: line) else { return nil }
        var value = String(line[range]).trimmingCharacters(in: .whitespaces)
        for suffix in ["입니다.", "입니다", "이에요.", "이에요", "예요.", "예요", "."] where value.hasSuffix(suffix) {
            value = String(value.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        return value.isEmpty ? nil : value
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
}
