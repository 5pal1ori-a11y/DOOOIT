import Foundation

/// 문제 유형 (채점 방법이 달라요)
enum ProblemKind: String, Codable, CaseIterable, Identifiable {
    case multipleChoice, shortAnswer, math, essay
    var id: String { rawValue }
    var title: String {
        switch self {
        case .multipleChoice: return "객관식"
        case .shortAnswer: return "단답형"
        case .math: return "수학 계산"
        case .essay: return "서술형"
        }
    }
}

/// 사진·글에서 읽은 문제를 나눠 정리한 것 (사용자가 확인하기 전까지는 "임시")
struct ProblemScan: Codable, Equatable {
    /// 불확실한 부분
    struct Doubt: Codable, Equatable, Hashable {
        var text: String
        var reason: String
    }

    var body: String = ""
    var formulas: [String] = []
    var choices: [String] = []
    var conditions: [String] = []
    var table: [[String]] = []
    var graphNote: String?
    /// 질문의 핵심 ("~을 구하시오", "~은?")
    var question: String = ""
    var kind: ProblemKind = .shortAnswer
    /// 사진 속에 적힌 정답 표기 (있을 때만)
    var printedAnswer: String?
    var doubts: [Doubt] = []
    /// 글로 자동으로 정한 과목 (노트 과목이 이 값과 같으면 사용자가 아직 직접 고르지 않은 것). 예전 노트는 nil
    var autoSubject: String?
    /// 문제 유형 사전(DoitProblemTypes)에서 찾은 유형 id
    var typeID: String?
    var boxItems: [String]?

    var hasDoubts: Bool { !doubts.isEmpty }

    /// 찾은 문제 유형
    var problemType: ProblemType? { typeID.flatMap(DoitProblemTypes.type(id:)) }
}

/// 문제 글을 본문·수식·선택지·조건·표·질문으로 나눔 (사진에서 확인할 수 없는 내용은 만들지 않음)
enum DoitProblemScan {
    /// - text: 읽은 글 (사용자가 고친 글이어도 됨)
    /// - lowConfidence: 글자 인식이 자신 없어 한 줄들
    /// - graphNote: 그림 분석 결과 (그래프가 있으면)
    /// - math: false면 수학이 아닌 과목 (수식 찾기·수학 유형 판단을 하지 않고, 정답 표기는 줄 맨 앞의 것만)
    static func scan(_ raw: String, lowConfidence: [String] = [], graphNote: String? = nil, math: Bool = true) -> ProblemScan {
        var result = ProblemScan()
        let text = raw.replacingOccurrences(of: "\r", with: "")
        var lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        // 1) 사진에 적힌 정답 ("정답: ③")은 문제에서 빼서 따로
        if let answer = math ? MathGrader.extractAnswer(from: text) : DoitSubjectNote.printedAnswer(in: text) {
            result.printedAnswer = answer
            lines.removeAll { $0.range(of: #"^(정답|답)\s*[:：)]"#, options: .regularExpression) != nil || (!math && DoitSubjectNote.printedAnswer(in: $0) != nil) }
        }

        // 2) 선택지: 줄마다 ①~⑤ / (1)~(5) / 1) ~ 5), 한 줄에 여러 개도
        var bodyLines: [String] = []
        for (index, line) in lines.enumerated() {
            // "3. 다음 중…" 같은 문제 번호는 선택지가 아님: "N."은 1부터 차례대로 이어질 때만 선택지
            if let m = line.firstMatch(of: #/^([1-5])\.\s/#), let n = Int(m.1) {
                let next = index + 1 < lines.count ? lines[index + 1] : ""
                let inSequence = n == result.choices.count + 1 && (n > 1 || next.hasPrefix("2."))
                if !inSequence { bodyLines.append(String(line.dropFirst(m.0.count))); continue }
            }
            let found = choices(in: line)
            if found.count >= 1, startsWithChoiceMark(line) {
                result.choices += found
            } else if found.count >= 3 {
                result.choices += found
            } else {
                bodyLines.append(line)
            }
        }

        // 3) 표: "|"로 나뉜 줄이나 숫자·낱말이 세 칸 이상 띄어 쓴 줄이 두 줄 넘게 이어지면
        var tableRows: [[String]] = []
        var keep: [String] = []
        for line in bodyLines {
            let cells = tableCells(line)
            if cells.count >= 3 { tableRows.append(cells) } else { keep.append(line) }
        }
        if tableRows.count >= 2 { result.table = tableRows; bodyLines = keep }

        result.body = bodyLines.joined(separator: "\n")

        // 4) 조건: "단," "(단 …)" "~일 때" "자연수·정수·실수·양수" 같은 제한
        let sentences = splitSentences(result.body)
        result.conditions = sentences.filter(isCondition)

        // 5) 질문의 핵심: "구하시오/고르시오/쓰시오/설명하시오/~은?" 문장
        result.question = sentences.last(where: isQuestion) ?? sentences.last ?? ""

        // 6) 수식: 수식다운 덩어리
        if math { result.formulas = formulas(in: result.body + "\n" + result.choices.joined(separator: "\n")) }

        result.graphNote = graphNote
        result.kind = guessKind(body: result.body, choices: result.choices, question: result.question, math: math)

        // 7) 불확실한 부분: 인식이 자신 없던 줄 + 수식이 이상한 곳
        var doubts: [ProblemScan.Doubt] = []
        for line in lowConfidence where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            doubts.append(.init(text: line, reason: "글자가 흐리거나 작아서 확실하지 않아요"))
        }
        for formula in result.formulas {
            if let reason = suspicious(formula) { doubts.append(.init(text: formula, reason: reason)) }
        }
        if result.kind == .multipleChoice, result.choices.count < 5, result.choices.count >= 2, numbered(result.choices) {
            doubts.append(.init(text: "선택지 \(result.choices.count)개", reason: "선택지가 5개가 아니에요. 빠진 보기가 없는지 확인해 주세요"))
        }
        if graphNote == nil, result.body.contains("그래프") || result.body.contains("그림") {
            doubts.append(.init(text: "그래프·그림", reason: "문제에 그래프나 그림이 있지만 내용을 읽지 못했어요. 필요한 값은 직접 적어 주세요"))
        }
        if result.body.count < 6 && result.choices.isEmpty {
            doubts.append(.init(text: "문제 본문", reason: "읽은 글이 너무 짧아요. 영역을 다시 고르거나 직접 적어 주세요"))
        }
        var seen = Set<String>()
        result.doubts = doubts.filter { seen.insert($0.text + $0.reason).inserted }
        return result
    }

    // MARK: - 선택지

    private static let circled: [Character] = ["①", "②", "③", "④", "⑤"]

    static func startsWithChoiceMark(_ line: String) -> Bool {
        guard let first = line.first else { return false }
        if circled.contains(first) { return true }
        return line.range(of: #"^(\(?[1-5]\)|[1-5]\.)\s"#, options: .regularExpression) != nil
    }

    /// 한 줄 안의 선택지들 ("① 2 ② 3 ③ 4" → ["2", "3", "4"])
    static func choices(in line: String) -> [String] {
        // ①②③④⑤
        if line.contains(where: { circled.contains($0) }) {
            var parts: [String] = []
            var current: String?
            for ch in line {
                if circled.contains(ch) {
                    if let c = current { parts.append(c.trimmingCharacters(in: .whitespaces)) }
                    current = ""
                } else if current != nil {
                    current?.append(ch)
                }
            }
            if let c = current { parts.append(c.trimmingCharacters(in: .whitespaces)) }
            return parts.filter { !$0.isEmpty }
        }
        // (1) … (2) … / 1) … 2) …
        let pattern = #"(?:^|\s)\(?([1-5])[)\.]\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return [] }
        // 번호가 1부터 차례대로일 때만 선택지로 봄 ("3. 다음 중…" 같은 문제 번호는 아님)
        let numbers = matches.map { Int(ns.substring(with: $0.range(at: 1))) ?? 0 }
        guard numbers.first == 1 || (matches.count == 1 && startsWithChoiceMark(line)), numbers == Array(numbers.first!..<(numbers.first! + numbers.count)) else { return [] }
        var parts: [String] = []
        for (i, m) in matches.enumerated() {
            let start = m.range.location + m.range.length
            let end = i + 1 < matches.count ? matches[i + 1].range.location : ns.length
            parts.append(ns.substring(with: NSRange(location: start, length: max(0, end - start))).trimmingCharacters(in: .whitespaces))
        }
        return parts.filter { !$0.isEmpty }
    }

    private static func numbered(_ choices: [String]) -> Bool { !choices.isEmpty }

    // MARK: - 표 · 문장 · 조건 · 질문

    static func tableCells(_ line: String) -> [String] {
        if line.contains("|") {
            return line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        let cells = line.components(separatedBy: "\t").flatMap { $0.components(separatedBy: "   ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return cells.count >= 3 && cells.allSatisfy { $0.count <= 12 } ? cells : []
    }

    static func splitSentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if ch == "?" || ch == "\n" || (ch == "." && !(current.dropLast().last?.isNumber ?? false)) {
                let s = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { result.append(s) }
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty { result.append(rest) }
        return result
    }

    static func isCondition(_ sentence: String) -> Bool {
        let s = sentence.replacingOccurrences(of: " ", with: "")
        if s.hasPrefix("단,") || s.hasPrefix("(단") || s.contains("(단,") || s.contains("(단 ") { return true }
        let words = ["자연수", "정수", "실수", "양수", "음수", "유리수", "≠", "이상", "이하", "초과", "미만", "서로다른", "중근", "범위", "조건"]
        return words.contains { s.contains($0) } && !isQuestion(sentence)
    }

    static func isQuestion(_ sentence: String) -> Bool {
        let s = sentence.replacingOccurrences(of: " ", with: "")
        let endings = ["구하시오", "구하여라", "구하라", "고르시오", "고른것은", "쓰시오", "설명하시오", "서술하시오", "나타내시오", "값은", "것은", "몇개", "?", "구해보세요", "구하세요"]
        return endings.contains { s.hasSuffix($0) || s.hasSuffix($0 + ".") || s.contains($0 + "?") }
    }

    static func guessKind(body: String, choices: [String], question: String, math: Bool = true) -> ProblemKind {
        if choices.count >= 3 { return .multipleChoice }
        let q = question.replacingOccurrences(of: " ", with: "")
        if ["서술하시오", "설명하시오", "논하시오", "까닭을쓰", "이유를쓰", "과정을쓰"].contains(where: { q.contains($0) }) { return .essay }
        if math, DoitMath.looksLikeMath(body) || MathSolver.solve(body) != nil { return .math }
        return .shortAnswer
    }

    // MARK: - 수식

    static func formulas(in text: String) -> [String] {
        var found: [String] = []
        for line in text.components(separatedBy: "\n") {
            let expression = DoitMath.extractExpression(line)
            if expression.count >= 3, expression.contains(where: { "=+-−×÷*/^²³√<>≤≥".contains($0) }) || expression.contains("x") {
                if !found.contains(expression) { found.append(expression) }
            }
        }
        return found
    }

    /// 잘못 읽었을 가능성이 큰 수식
    static func suspicious(_ formula: String) -> String? {
        let opens = formula.filter { $0 == "(" }.count, closes = formula.filter { $0 == ")" }.count
        if opens != closes { return "괄호 짝이 맞지 않아요" }
        if formula.range(of: #"[+\-−×÷*/=]{2,}"#, options: .regularExpression) != nil, !formula.contains("->") { return "기호가 겹쳐 있어요" }
        if formula.range(of: #"(^|[^a-z])[lIO|](?=[0-9x+\-])"#, options: .regularExpression) != nil { return "l·I·O·| 가 숫자 1이나 0일 수 있어요" }
        if formula.hasSuffix("=") || formula.hasPrefix("=") { return "등식 한쪽이 비어 있어요" }
        if formula.range(of: #"x[0-9]{2,}"#, options: .regularExpression) != nil { return "지수(제곱)가 숫자로 읽혔을 수 있어요" }
        return nil
    }
}
