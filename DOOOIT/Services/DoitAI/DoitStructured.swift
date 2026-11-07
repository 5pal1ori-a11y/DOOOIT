import Foundation

/// 공부 질문에 대한 구조화된 답: 한 줄 답 → 핵심 · 풀이 · 주의 · 예시 · 다음 연습 (+ 비교 표)
/// 엔진이 이미 만든 답이나 앱 안 자료(지식 사전 · 영문법 단원)에 있는 글만 나눠 담아요.
/// 자료에 없는 칸(주의, 비교 줄 등)은 비워 두고 지어내지 않아요.
struct DoitStructuredAnswer: Equatable {
    struct Section: Equatable {
        var label: String
        var lines: [String]
    }

    struct Table: Equatable {
        var header: [String]
        var rows: [[String]]
    }

    /// 주제 이름 ("이차방정식")
    var title: String
    /// 한 줄 답
    var headline: String
    /// 한 줄 답 앞에 붙이는 이름 (수학은 "답")
    var headlineLabel: String? = nil
    var sections: [Section] = []
    var table: Table? = nil
    /// 이 주제로 변형 문제를 한 번 더 풀 수 있을 때만
    var practice: VariantTopic? = nil

    /// 구조 없이 이어 붙인 글 (복사 · 접근성)
    var plainText: String {
        var lines = [title, (headlineLabel.map { $0 + ": " } ?? "") + headline]
        for section in sections { lines.append(section.label); lines += section.lines }
        if let table {
            lines.append(table.header.joined(separator: " | "))
            lines += table.rows.map { $0.joined(separator: " | ") }
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

enum DoitStructured {
    /// 변형 문제를 여는 추천 칩 (엔진이 낼 수 있는 주제일 때만 붙임)
    static let practiceChip = "변형 문제 풀기"

    static let practiceLabel = "다음 연습"

    // MARK: - 엔진 답 → 구조

    /// 엔진 답을 구조로 (구조로 나눌 만큼 길고 규칙적인 공부 답만, 아니면 nil)
    static func build(text: String, origin: DoitEngine.Origin, question: String) -> DoitStructuredAnswer? {
        if text.contains("\n**답:") || text.contains("\n\n**답:") {
            return math(text, question: question)
        }
        guard text.hasPrefix("**"), origin == .knowledge || origin == .subject else { return nil }
        // 숫자가 든 과목 질문은 계산·단위 바꾸기 답이라 그대로 (구조로 나누지 않음)
        if origin == .subject, question.contains(where: \.isNumber) { return nil }
        return knowledge(text)
    }

    // MARK: 수학 풀이

    static func math(_ text: String, question: String) -> DoitStructuredAnswer? {
        let lines = text.components(separatedBy: "\n")
        guard let first = lines.first, first.hasPrefix("**"), first.hasSuffix("**"), first.count > 4 else { return nil }
        let title = String(first.dropFirst(2).dropLast(2))
        var concept = ""
        var steps: [String] = []
        var answer: String?
        for raw in lines.dropFirst() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("💡") {
                concept = line.dropFirst(1).trimmingCharacters(in: .whitespaces)
            } else if let m = line.firstMatch(of: #/^\*\*답:\s*(.+?)\*\*$/#) {
                answer = String(m.1)
            } else if let m = line.firstMatch(of: #/^\d+\.\s*(.+)$/#) {
                steps.append(String(m.1))
            } else if line.hasPrefix("→"), !steps.isEmpty {
                let work = line.dropFirst(1).trimmingCharacters(in: .whitespaces)
                if !work.isEmpty { steps[steps.count - 1] += " → " + work }
            }
        }
        guard let answer, !answer.isEmpty, !steps.isEmpty else { return nil }
        var result = DoitStructuredAnswer(title: title, headline: answer, headlineLabel: "답")
        if !concept.isEmpty { result.sections.append(.init(label: "핵심", lines: [concept])) }
        result.sections.append(.init(label: "풀이", lines: steps))
        result.practice = DoitVariants.topic(forProblem: question)
        return result
    }

    // MARK: 개념 설명

    private static let cautionCues = ["주의", "헷갈", "혼동", "함께 못", "같이 못", "쓰지 않", "쓰면 안", "하면 안", "구분해서", "착각"]
    private static let relatedPrefixes = ["관련 인물", "같은 해", "관련 개념", "함께 보면"]

    static func knowledge(_ text: String) -> DoitStructuredAnswer? {
        var lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let head = lines.first, head.hasPrefix("**") else { return nil }
        lines.removeFirst()
        // "**광합성** (과학)" → 광합성 · "**현재완료 (have / has + p.p.)**" → 그대로
        var title = head
        if let m = head.firstMatch(of: #/^\*\*(.+?)\*\*/#) { title = String(m.1) }
        let entry = DoitKnowledge.entry(named: title.components(separatedBy: " (").first ?? title)
        // 함께 보면 좋은 개념 줄
        var related: [String] = []
        var body: [String] = []
        for line in lines where !line.isEmpty {
            if line.hasPrefix("함께 보면 좋아요:") {
                related.append(String(line.dropFirst("함께 보면 좋아요:".count)).trimmingCharacters(in: .whitespaces))
            } else {
                body.append(line)
            }
        }
        guard body.count >= 1 else { return nil }

        // 비교 표: "순물질: …", "혼합물: …"처럼 이름 있는 줄이 둘 이상이고, 그 이름이 모두 이 개념의 이름일 때
        var table: DoitStructuredAnswer.Table?
        if let entry {
            let labeled = body.compactMap { line -> (String, String)? in
                guard let m = line.firstMatch(of: #/^([^:：]{1,14})[:：]\s*(.+)$/#) else { return nil }
                return (String(m.1), String(m.2))
            }
            let names = Set(entry.names.map { $0.filter { !$0.isWhitespace } })
            if labeled.count >= 2, labeled.count == body.count, labeled.allSatisfy({ names.contains($0.0.filter { !$0.isWhitespace }) }) {
                table = .init(header: ["구분", "뜻"], rows: labeled.map { [$0.0, $0.1] })
                body = []
            }
        }
        if let table {
            var result = DoitStructuredAnswer(title: title, headline: table.rows.map { $0[0] }.joined(separator: " · "), table: table)
            if !related.isEmpty { result.sections.append(.init(label: "관련", lines: related)) }
            result.practice = DoitVariants.topic(forConcept: entry?.title ?? title)
            return result
        }

        // 한 줄 답: 첫 줄의 첫 문장
        let firstLine = body.removeFirst().replacingOccurrences(of: "• ", with: "")
        let sentences = split(firstLine)
        let headline = sentences.first ?? firstLine
        guard headline.count <= 130 else { return nil }
        var rest = sentences.dropFirst().map { $0 }
        rest += body.map { $0.hasPrefix("• ") ? String($0.dropFirst(2)) : $0 }

        var core: [String] = [], caution: [String] = [], example: [String] = [], extra: [String] = [], tip: [String] = []
        var inExample = false
        for line in rest {
            if line == "예문" || line == "예시" { inExample = true; continue }
            if inExample || line.hasPrefix("예:") || line.hasPrefix("예)") || line.range(of: #"^\d+\)"#, options: .regularExpression) != nil {
                example.append(line.hasPrefix("예:") ? String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces) : line)
            } else if relatedPrefixes.contains(where: { line.hasPrefix($0) }) {
                extra.append(line)
            } else if line.hasPrefix("암기 팁") {
                tip.append(line.replacingOccurrences(of: "암기 팁:", with: "").trimmingCharacters(in: .whitespaces))
            } else if cautionCues.contains(where: { line.contains($0) }) {
                caution.append(line)
            } else {
                core.append(line)
            }
        }
        // 영문법 단원이면 자주 틀리는 곳 · 예문을 단원 자료에서 (답에 없을 때만)
        var practiceTitle = entry?.title ?? title
        if let unit = DoitGrammar.find(title.components(separatedBy: " (").first ?? title).first {
            practiceTitle = unit.name
            if caution.isEmpty, let trap = unit.traps.first, !rest.contains(where: { $0.contains(trap) }) { caution.append(trap) }
            if example.isEmpty, let ex = unit.examples.first { example.append(ex) }
        }
        var result = DoitStructuredAnswer(title: title, headline: headline)
        if !core.isEmpty { result.sections.append(.init(label: "핵심", lines: Array(core.prefix(4)))) }
        if !caution.isEmpty { result.sections.append(.init(label: "주의", lines: Array(caution.prefix(2)))) }
        if !example.isEmpty { result.sections.append(.init(label: "예시", lines: Array(example.prefix(3)))) }
        if !tip.isEmpty { result.sections.append(.init(label: "팁", lines: Array(tip.prefix(1)))) }
        if !extra.isEmpty || !related.isEmpty { result.sections.append(.init(label: "관련", lines: Array((extra + related).prefix(3)))) }
        // 한 줄 답만 있고 나눌 게 없으면 구조로 보여 줄 이유가 없음
        guard !result.sections.isEmpty else { return nil }
        result.practice = DoitVariants.topic(forConcept: practiceTitle)
        return result
    }

    /// 문장 나누기: 한글 뒤의 마침표만 (p.p. · e.g. 같은 영어 줄임말, 영어 예문은 나누지 않음)
    static func split(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        let chars = Array(text)
        for (i, ch) in chars.enumerated() {
            current.append(ch)
            guard ".!?".contains(ch) else { continue }
            let next = i + 1 < chars.count ? chars[i + 1] : " "
            let prev = i > 0 ? chars[i - 1] : " "
            let hangul = prev.unicodeScalars.first.map { (0xAC00...0xD7A3).contains($0.value) } ?? false
            if next == " ", hangul || ")]」\"'".contains(prev) {
                out.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { out.append(rest) }
        return out.filter { $0.count >= 2 }
    }

    // MARK: - 비교 표

    /// "A와 B의 차이" 질문에서 두 이름
    static func comparedNames(in question: String) -> (String, String)? {
        let t = question.lowercased().replacingOccurrences(of: " ", with: "")
        let cue = "(?:의)?(?:차이점|차이|다른점|비교|구분|구별)"
        let patterns = [#"^(.{1,16}?)(?:이랑|랑|하고|과|와)(.{1,16}?)"# + cue, #"^(.{1,16}?)(?:vs|대)(.{1,16}?)"# + cue]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let m = regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)), m.numberOfRanges == 3,
                  let a = Range(m.range(at: 1), in: t), let b = Range(m.range(at: 2), in: t) else { continue }
            let left = String(t[a]), right = String(t[b])
            if left != right { return (left, right) }
        }
        return nil
    }

    /// 두 개념을 자료에서 찾아 표로 (둘 다 정확한 이름으로 찾고, 줄이 둘 이상 나올 때만)
    static func comparison(_ question: String) -> DoitStructuredAnswer? {
        guard let (rawA, rawB) = comparedNames(in: question) else { return nil }
        if let a = DoitGrammar.find(rawA).first, let b = DoitGrammar.find(rawB).first, a.name != b.name {
            return grammarComparison(a, b)
        }
        // 지식 사전: 이름이 정확히 같은 두 개념 (같은 과목)
        guard let a = DoitKnowledge.entry(named: rawA), let b = DoitKnowledge.entry(named: rawB),
              a.title != b.title, a.subject == b.subject else { return nil }
        return knowledgeComparison(a, b)
    }

    private static func firstSentence(_ text: String) -> String {
        let line = text.components(separatedBy: "\n").first ?? text
        return split(line).first ?? line
    }

    private static func knowledgeComparison(_ a: DoitKnowledge.Entry, _ b: DoitKnowledge.Entry) -> DoitStructuredAnswer? {
        func sentences(_ e: DoitKnowledge.Entry) -> [String] { e.body.components(separatedBy: "\n").flatMap { split($0) } }
        func example(_ e: DoitKnowledge.Entry) -> String? {
            e.body.firstMatch(of: #/\(?예:\s*([^)\n]+)\)?/#).map { String($0.1).trimmingCharacters(in: .whitespaces) }
        }
        func caution(_ e: DoitKnowledge.Entry) -> String? { sentences(e).first { s in cautionCues.contains { s.contains($0) } } }
        var rows: [[String]] = [["뜻", firstSentence(a.body), firstSentence(b.body)]]
        if let ea = example(a), let eb = example(b) { rows.append(["예", ea, eb]) }
        let extraA = sentences(a).dropFirst().first { s in !cautionCues.contains { s.contains($0) } && !s.contains("예:") }
        let extraB = sentences(b).dropFirst().first { s in !cautionCues.contains { s.contains($0) } && !s.contains("예:") }
        if let x = extraA, let y = extraB { rows.append(["특징", x, y]) }
        if let ca = caution(a), let cb = caution(b) { rows.append(["주의", ca, cb]) }
        guard rows.count >= 2 else { return nil }
        var result = DoitStructuredAnswer(title: "\(a.title) · \(b.title)", headline: "\(a.title) vs \(b.title)",
                                          table: .init(header: ["", a.title, b.title], rows: rows))
        result.practice = DoitVariants.topic(forConcept: a.title)
        return result
    }

    private static func grammarComparison(_ a: GrammarUnit, _ b: GrammarUnit) -> DoitStructuredAnswer? {
        var rows: [[String]] = []
        if !a.summary.isEmpty, !b.summary.isEmpty { rows.append(["핵심", a.summary, b.summary]) }
        if let pa = a.points.first, let pb = b.points.first { rows.append(["쓰임", pa, pb]) }
        if let ea = a.examples.first, let eb = b.examples.first { rows.append(["예문", ea, eb]) }
        if let ta = a.traps.first, let tb = b.traps.first { rows.append(["주의", ta, tb]) }
        guard rows.count >= 2 else { return nil }
        var result = DoitStructuredAnswer(title: "\(a.name) · \(b.name)", headline: "\(a.name) vs \(b.name)",
                                          table: .init(header: ["", a.name, b.name], rows: rows))
        result.practice = DoitVariants.topic(forConcept: a.name)
        return result
    }

    // MARK: - 이어 묻기 추천

    /// 추천 칩 (엔진이 실제로 할 수 있는 것만, 최대 3개)
    /// - 변형 문제: 이 주제로 문제를 낼 수 있을 때
    /// - 더 쉽게 · 예시 · 왜: 지금 대화 상태로 이어 말하기를 풀 수 있을 때
    /// - 비교 표: 비교한 두 개념을 각각 설명하기 (엔진이 "**"로 시작하는 설명을 내는 것만)
    @MainActor
    static func chips(for answer: DoitStructuredAnswer, existing: [String], state: DoitDialogue.State) -> [String] {
        var chips: [String] = []
        if answer.practice != nil { chips.append(practiceChip) }
        if let table = answer.table, table.header.count == 3 {
            for name in table.header.dropFirst() {
                let ask = "\(name) 설명해줘"
                if DoitEngine.respond(to: ask, photo: nil).text.hasPrefix("**") { chips.append(ask) }
            }
            return Array(chips.prefix(3))
        }
        let probes: [(chip: String, probe: String)] = [("더 쉽게 설명해줘", "더 쉽게"), ("예시 보여줘", "예시"), ("왜 그래?", "왜?")]
        for item in probes where viable(item.probe, state: state) { chips.append(item.chip) }
        for suggestion in existing where !chips.contains(suggestion) {
            // 변형 문제 칩이 있으면 대화로 비슷한 문제를 내는 칩은 겹침
            if answer.practice != nil, suggestion == "비슷한 문제 내줘" { continue }
            chips.append(suggestion)
        }
        return Array(chips.prefix(3))
    }

    /// 이어 말하기가 실제 답이 나오는지 ("준비된 게 없어요" · 되묻기는 제외)
    static func viable(_ probe: String, state: DoitDialogue.State) -> Bool {
        switch DoitDialogue.resolve(probe, state: state) {
        case .rewrite: return true
        case .answer(let text, _): return !text.contains("준비된 게 없어요") && !text.contains("자료에 없어요")
        case .clarify, .none: return false
        }
    }
}
