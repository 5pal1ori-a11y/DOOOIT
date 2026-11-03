import Foundation

// MARK: - 과목 풀이 더하기: 어법 문장 고르기 · 보기 항목 규칙 판단 · 두 빈칸 (A)(B)

extension DoitSubjectSolve {
    // MARK: 어법상 어색한(옳은) 문장

    /// 선지가 영어 문장인 "어법상 어색한 것은?" · "어법상 옳은 문장은?"
    /// - 어색한 것 하나: 규칙으로 확실히 틀린 문장이 하나뿐일 때 (시험은 틀린 문장이 하나라서, 확실히 틀린 문장이 곧 답)
    /// - 옳은 것 하나: 나머지가 모두 확실히 틀렸을 때
    static func englishSentences(_ p: Problem) -> Found? {
        let c = p.compact
        guard p.isChoice, p.box.isEmpty, c.contains("어법"), !matches(c, #"(개수|몇개|모두|있는대로|문맥|밑줄)"#),
              p.choices.allSatisfy(DoitSentenceCheck.isEnglishSentence) else { return nil }
        let issues = p.choices.map(DoitSentenceCheck.error(in:))
        let bad = issues.indices.filter { issues[$0] != nil }
        let steps = p.choices.indices.map { i -> SolutionStep in
            if let issue = issues[i] { return SolutionStep(hint: issue.rule, work: "\(circled(i + 1)) \(p.choices[i]) → \(issue.why)") }
            return SolutionStep(hint: "", work: "\(circled(i + 1)) \(p.choices[i]) → 규칙으로 틀린 곳을 찾지 못했어요")
        }
        if p.negated || c.contains("어색") {
            guard bad.count == 1 else { return nil }
            return pick(p, index: bad[0], concept: "어법: " + (issues[bad[0]]?.rule ?? ""), steps: steps)
        }
        guard bad.count == p.choices.count - 1, let good = p.choices.indices.first(where: { issues[$0] == nil }) else { return nil }
        return pick(p, index: good, concept: "어법 (나머지는 모두 틀린 곳이 있어요)", steps: steps)
    }

    // MARK: 보기 항목 (a)~e), ㄱ~ㄹ) 규칙으로 판단

    /// 항목 하나를 규칙·자료로 판단: false 확실히 틀림, true 확실히 맞음, nil 모름
    static func ruleVerdict(_ item: DoitItemJudge.Item, stem: String) -> (verdict: Bool, why: String)? {
        let c = stem.filter { !$0.isWhitespace }
        if DoitSentenceCheck.isEnglishSentence(item.text) {
            guard c.contains("어법") || c.contains("문법") else { return nil }
            if let issue = DoitSentenceCheck.error(in: item.text) { return (false, issue.why) }
            return nil
        }
        // 맞춤법 항목
        if matches(c, #"(맞춤법|표준어|바르게쓴|표기)"#) {
            if let w = wrongSpelling(in: item.text) { return (false, "'\(w.wrong)' → '\(w.right)'") }
            return nil
        }
        // 설명 문장: 묻는 개념의 사실표
        if let claim = askedClaim(stem), let v = judgeClaim(claim, item.text) { return (v, v ? "자료와 맞아요" : "자료와 달라요") }
        return nil
    }

    /// 항목 판단 몇 개로 고를 수 있는 선지 (확실한 판단만으로 다른 선지를 모두 지울 수 있을 때)
    /// - 옳은 것 고르기: 틀린 항목이 든 선지는 답이 아님, "있는 대로"면 맞는 항목이 빠진 선지도 답이 아님
    /// - 틀린 것 고르기: 반대로
    static func eliminate(_ s: DoitItemJudge.Setup, known: [String: Bool]) -> Int? {
        let rejected = s.wantTrue ? Set(known.filter { !$0.value }.keys) : Set(known.filter { $0.value }.keys)
        let required = s.wantTrue ? Set(known.filter { $0.value }.keys) : Set(known.filter { !$0.value }.keys)
        var candidates = s.choiceSets.indices.filter { s.choiceSets[$0].isDisjoint(with: rejected) }
        if s.exact { candidates = candidates.filter { required.isSubset(of: s.choiceSets[$0]) } }
        else if !s.wantTrue {
            // 틀린 것끼리(있는 대로가 아님): 확실히 틀린 항목만 든 선지가 하나면 그것
            let sure = s.choiceSets.indices.filter { s.choiceSets[$0].isSubset(of: required) }
            return sure.count == 1 ? sure[0] : nil
        }
        return candidates.count == 1 ? candidates[0] : nil
    }

    static func itemRules(_ p: Problem) -> Found? {
        guard p.isChoice, let s = DoitItemJudge.setup(text: p.full, body: nil, choices: p.choices, boxItems: p.box.isEmpty ? nil : p.box) else { return nil }
        var known: [String: Bool] = [:]
        var reasons: [String: String] = [:]
        for item in s.items {
            if let r = ruleVerdict(item, stem: s.stem) { known[item.label] = r.verdict; reasons[item.label] = r.why }
        }
        guard !known.isEmpty, let index = eliminate(s, known: known) else { return nil }
        let steps = s.items.map { it -> SolutionStep in
            if let v = known[it.label] { return SolutionStep(hint: "", work: "\(it.label)) \(v ? "O" : "X") · \(reasons[it.label] ?? "")") }
            return SolutionStep(hint: "", work: "\(it.label)) 규칙으로는 판단하지 않았어요 (남은 선지로 정해져요)")
        }
        return pick(p, index: index, concept: s.wantTrue ? "항목을 하나씩 따져 틀린 것이 든 선지를 지워요" : "항목을 하나씩 따져 틀린 것만 골라요", steps: steps)
    }

    // MARK: 두 빈칸 (A), (B)

    static func englishTwoBlanks(_ p: Problem) -> Found? {
        guard p.isChoice, p.full.contains("(A)"), p.full.contains("(B)"), !p.full.contains("["), !p.full.contains("［") else { return nil }
        // 선지: "who - which"
        let split = p.choices.map { $0.components(separatedBy: CharacterSet(charactersIn: "-–/")).map { $0.trimmingCharacters(in: .whitespaces) } }
        guard split.allSatisfy({ $0.count == 2 && $0.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isASCII) } }) else { return nil }
        // 빈칸이 있는 영어 줄
        let lines = p.full.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        var solved: [Int: String] = [:]
        var steps: [SolutionStep] = []
        for (slot, label) in ["(A)", "(B)"].enumerated() {
            guard let line = lines.first(where: { $0.contains(label) && !$0.contains(where: { DoitSubjectNote.isHangul($0) }) }) else { continue }
            var sentence = line.replacingOccurrences(of: label, with: "______")
            for other in ["(A)", "(B)", "(C)"] where other != label { sentence = sentence.replacingOccurrences(of: other, with: "") }
            var options: [String] = []
            for parts in split where !options.contains(parts[slot]) { options.append(parts[slot]) }
            guard options.count >= 2 else { continue }
            let sub = Problem(full: sentence, body: sentence, choices: options, box: [])
            guard let found = englishGrammar(sub), let n = Int(found.answer), n >= 1, n <= options.count else { continue }
            solved[slot] = options[n - 1]
            steps.append(SolutionStep(hint: label, work: "\(sentence.replacingOccurrences(of: "______", with: "[\(options[n - 1])]")) · " + found.concept))
        }
        guard !solved.isEmpty else { return nil }
        let hits = split.indices.filter { i in solved.allSatisfy { split[i][$0.key].lowercased() == $0.value.lowercased() } }
        guard hits.count == 1 else { return nil }
        return pick(p, index: hits[0], concept: "두 빈칸의 어법", steps: steps)
    }
}
