import Foundation

/// 문법 단원 → AI 학습 단계(개념 · 빈칸 · O/X · 문제)와 모의고사 문제
/// 화면은 그대로 두고 같은 자료 형식(ConceptNote · ClozeItem · OXItem · Problem · PracticeItem)으로 바꿔요.
extension DoitGrammar {
    // MARK: - 데이터 파일용 짧은 도우미

    /// 빈칸 고르기 (오답 보기를 넣은 문장은 어법상 틀려야 함)
    static func b(_ s: String, _ a: String, _ wrong: [String], _ note: String, hint: String? = nil, ko: String? = nil, alt: [String] = []) -> GrammarItem {
        GrammarItem(kind: .blank, text: s, answer: a, wrong: wrong, note: note, hint: hint, ko: ko, alternatives: alt)
    }

    /// 영어 문장 어법 O/X
    static func ox(_ s: String, _ ok: Bool, _ note: String) -> GrammarItem {
        GrammarItem(kind: .ox, text: s, answer: ok ? "O" : "X", wrong: [], note: note)
    }

    /// 규칙 설명 O/X (한국어)
    static func rl(_ s: String, _ ok: Bool, _ note: String) -> GrammarItem {
        GrammarItem(kind: .rule, text: s, answer: ok ? "O" : "X", wrong: [], note: note)
    }

    /// 틀린 곳 고치기: 문장, 틀린 부분, 고친 표현
    static func fx(_ s: String, _ part: String, _ fixed: String, _ note: String, alt: [String] = [], avoid: [String] = []) -> GrammarItem {
        GrammarItem(kind: .fix, text: s, answer: fixed, wrong: [part], note: note, alternatives: alt, avoid: avoid)
    }

    /// 배열 (문장 하나로만 배열되는 것)
    static func ord(_ s: String, _ note: String) -> GrammarItem {
        GrammarItem(kind: .order, text: s, answer: s, wrong: [], note: note)
    }

    /// 해석 고르기
    static func mn(_ s: String, _ a: String, _ wrong: [String], _ note: String) -> GrammarItem {
        GrammarItem(kind: .meaning, text: s, answer: a, wrong: wrong, note: note)
    }

    /// 문장 전환: 할 일, 원래 문장, 바꾼 문장(빈칸), 정답, 오답
    static func tr(_ instruction: String, _ from: String, _ to: String, _ a: String, _ wrong: [String], _ note: String, alt: [String] = []) -> GrammarItem {
        GrammarItem(kind: .transform, text: to, answer: a, wrong: wrong, note: note, from: from, instruction: instruction, alternatives: alt)
    }

    static func u(_ level: SchoolLevel, _ name: String, _ grades: [Int], _ aliases: [String], summary: String, points: [String],
                  examples: [String], traps: [String], covers: [String] = [], items: [GrammarItem]) -> GrammarUnit {
        GrammarUnit(level: level, name: name, grades: grades, aliases: aliases, summary: summary, points: points,
                    examples: examples, traps: traps, items: items, covers: covers)
    }

    // MARK: - 1. 개념 정리

    static let source = "모티 영문법 단원 (교과서 순서 · 예문 어법 검사)"

    static func concept(_ list: [GrammarUnit], scope: StudyScope) -> ConceptNote {
        guard let first = list.first else { return ConceptNote(title: scope.unit, keyPoints: [], example: "") }
        if list.count == 1 {
            return ConceptNote(title: first.name, keyPoints: first.points, example: first.examples.joined(separator: "\n"),
                               summary: first.summary, details: first.traps.map { "함정 — " + $0 }, scope: scope.label,
                               sources: [source], checks: ["단원 일치", "예문 어법 검사", "정답 하나 확인"])
        }
        // 여러 문법 단원을 함께 쓰는 단원 (공통영어 "시제와 태" 등)
        let names = list.map(\.name)
        return ConceptNote(title: scope.unit, keyPoints: list.flatMap { unit in unit.points.prefix(2).map { "[\(unit.name)] " + $0 } },
                           example: list.flatMap { $0.examples.prefix(1) }.joined(separator: "\n"),
                           summary: "이 단원에서는 " + names.joined(separator: ", ") + "을(를) 함께 정리해요. " + first.summary,
                           details: list.flatMap { unit in unit.traps.prefix(1).map { "함정 (\(unit.name)) — " + $0 } }, scope: scope.label,
                           sources: [source], checks: ["단원 일치", "예문 어법 검사", "정답 하나 확인"])
    }

    // MARK: - 2. 빈칸 쓰기

    /// 화면에 보여 줄 빈칸 문장
    static func display(_ text: String) -> String { text.replacingOccurrences(of: blankMark, with: DoitStudyCheck.blank) }

    /// 빈칸 문제 글 (힌트가 없으면 보기를 괄호에)
    static func blankPrompt(_ item: GrammarItem) -> String {
        var text = display(item.text)
        if let hint = item.hint { text += " (\(hint))" } else { text += " [" + choiceList(item).joined(separator: " / ") + "]" }
        if let ko = item.ko { text += "\n뜻: \(ko)" }
        return text
    }

    /// 보기 (정답 + 오답 4개까지, 늘 같은 순서)
    static func choiceList(_ item: GrammarItem) -> [String] {
        seededShuffle([item.answer] + item.wrong.prefix(4), seed: item.text + item.answer)
    }

    /// 정답 글 (같이 인정하는 답은 " / "로)
    static func answerText(_ item: GrammarItem) -> String { ([item.answer] + item.alternatives).joined(separator: " / ") }

    static func clozeItems(_ list: [GrammarUnit]) -> [ClozeItem] {
        var result: [ClozeItem] = []
        for item in list.flatMap(\.items) {
            switch item.kind {
            case .blank:
                result.append(ClozeItem(sentence: blankPrompt(item), answer: answerText(item)))
            case .transform:
                result.append(ClozeItem(sentence: "\(item.instruction ?? "문장을 바꿔 쓰세요.")\n\(item.from ?? "")\n→ \(display(item.text))", answer: answerText(item)))
            case .fix:
                guard let part = item.wrong.first else { continue }
                result.append(ClozeItem(sentence: "\(item.text)\n어법상 틀린 '\(part)'을(를) 바르게 고치면? → \(DoitStudyCheck.blank)", answer: answerText(item)))
            default: continue
            }
        }
        return result
    }

    // MARK: - 3. O/X

    static func oxStatement(_ sentence: String) -> String { "이 문장은 어법상 바르다.\n\(sentence)" }

    static func oxItems(_ list: [GrammarUnit]) -> [OXItem] {
        var result: [OXItem] = []
        var seen = Set<String>()
        func add(_ item: OXItem) { if seen.insert(item.statement).inserted { result.append(item) } }
        for item in list.flatMap(\.items) {
            switch item.kind {
            case .rule:
                add(OXItem(statement: item.text, isTrue: item.answer == "O", explanation: (item.answer == "O" ? "맞아요. " : "틀려요. ") + item.note))
            case .ox:
                add(OXItem(statement: oxStatement(item.text), isTrue: item.answer == "O", explanation: (item.answer == "O" ? "맞아요. " : "틀려요. ") + item.note))
            case .fix:
                guard let part = item.wrong.first, let right = corrected(item) else { continue }
                add(OXItem(statement: oxStatement(item.text), isTrue: false, explanation: "틀려요. '\(part)' → '\(item.answer)'. \(item.note)"))
                add(OXItem(statement: oxStatement(right), isTrue: true, explanation: "맞아요. \(item.note)"))
            case .blank, .transform:
                guard item.ko == nil else { continue }
                add(OXItem(statement: oxStatement(filled(item.text, item.answer)), isTrue: true, explanation: "맞아요. \(item.note)"))
                if let wrong = item.wrong.first {
                    add(OXItem(statement: oxStatement(filled(item.text, wrong)), isTrue: false, explanation: "틀려요. '\(wrong)' 대신 '\(item.answer)'. \(item.note)"))
                }
            case .order:
                add(OXItem(statement: oxStatement(item.text), isTrue: true, explanation: "맞아요. \(item.note)"))
            case .meaning:
                continue
            }
        }
        return result
    }

    // MARK: - 4. 객관식 문제

    /// 문제와 종류 (고를 때 종류를 섞으려고)
    struct Tagged {
        let tag: String
        let problem: Problem
    }

    static func problem(_ question: String, choices: [String], answer: String, steps: [String]) -> Problem? {
        guard let index = choices.firstIndex(of: answer), choices.filter({ $0 == answer }).count == 1 else { return nil }
        return Problem(question: question, choices: choices, answerNumber: index + 1, steps: steps, finalAnswer: "\(index + 1)번 \(answer)")
    }

    static func taggedProblems(_ list: [GrammarUnit]) -> [Tagged] {
        var result: [Tagged] = []
        for item in list.flatMap(\.items) {
            if let made = problem(for: item) { result.append(Tagged(tag: item.kind.rawValue, problem: made)) }
        }
        result += composites(list).map { Tagged(tag: "composite", problem: $0) }
        return result
    }

    static func problems(_ list: [GrammarUnit]) -> [Problem] { taggedProblems(list).map(\.problem) }

    /// 문제 하나 (만들 수 없으면 nil)
    static func problem(for item: GrammarItem) -> Problem? {
        switch item.kind {
        case .blank:
            var question = "빈칸에 알맞은 말은?\n\(display(item.text))"
            if let ko = item.ko { question += "\n(뜻: \(ko))" }
            return problem(question, choices: choiceList(item), answer: item.answer,
                           steps: ["빈칸에는 '\(item.answer)'이(가) 알맞아요.", item.note])
        case .transform:
            return problem("\(item.instruction ?? "문장을 바꿀 때 빈칸에 알맞은 말은?")\n\(item.from ?? "")\n→ \(display(item.text))",
                           choices: choiceList(item), answer: item.answer, steps: ["바꾼 문장: \(filled(item.text, item.answer))", item.note])
        case .meaning:
            return problem("다음 문장의 뜻으로 알맞은 것은?\n\(item.text)", choices: choiceList(item), answer: item.answer,
                           steps: ["뜻: \(item.answer)", item.note])
        case .fix:
            guard let part = item.wrong.first else { return nil }
            let choices = fixChoices(item)
            guard choices.count >= 3, let right = corrected(item) else { return nil }
            return problem("다음 문장에서 어법상 틀린 부분은?\n\(item.text)", choices: choices, answer: part,
                           steps: ["틀린 곳: '\(part)' → '\(item.answer)'", "바른 문장: \(right)", item.note])
        case .order:
            guard let made = orderQuestion(item) else { return nil }
            return problem(made.question, choices: made.choices, answer: made.answer, steps: ["바른 문장: \(item.text)", item.note])
        case .ox, .rule:
            return nil
        }
    }

    /// 틀린 곳 찾기 보기: 틀린 부분 + 문장의 다른 낱말 (첫 낱말·피할 낱말 빼고), 문장 순서대로
    static func fixChoices(_ item: GrammarItem) -> [String] {
        guard let part = item.wrong.first, let range = wordRange(of: part, in: item.text) else { return [] }
        let partWords = Set(tokens(part).map { $0.lowercased() })
        let avoid = Set(item.avoid.map { $0.lowercased() })
        let all = tokens(item.text)
        var others: [String] = []
        for (index, word) in all.enumerated() where index > 0 {
            let lower = word.lowercased()
            guard !partWords.contains(lower), !avoid.contains(lower), lower.count >= 2 || lower == "a",
                  !others.contains(where: { $0.lowercased() == lower }), !part.lowercased().contains(lower) else { continue }
            others.append(word)
        }
        // 고르게 4개까지
        if others.count > 4 {
            let step = Double(others.count) / 4
            others = (0..<4).map { others[Int(Double($0) * step)] }
        }
        // 문장 순서대로 (틀린 부분 위치 포함)
        let partStart = item.text.distance(from: item.text.startIndex, to: range.lowerBound)
        var placed: [(Int, String)] = [(partStart, part)]
        for word in others {
            if let r = wordRange(of: word, in: item.text) { placed.append((item.text.distance(from: item.text.startIndex, to: r.lowerBound), word)) }
        }
        return placed.sorted { $0.0 < $1.0 }.map(\.1)
    }

    /// 배열 문제: k번째 낱말 고르기 (낱말이 겹치지 않는 자리)
    static func orderQuestion(_ item: GrammarItem) -> (question: String, choices: [String], answer: String)? {
        let words = tokens(item.text)
        guard words.count >= 4 else { return nil }
        let lower = words.map { $0.lowercased() }
        let middle = words.count / 2
        let positions = [middle, middle + 1, middle - 1, 1, words.count - 2].filter { $0 > 0 && $0 < words.count }
        guard let k = positions.first(where: { p in lower.filter { $0 == lower[p] }.count == 1 }) else { return nil }
        let answer = words[k]
        let shuffled = scrambled(item)
        var choices: [String] = [answer]
        for word in seededShuffle(shuffled, seed: item.text + "보기") where choices.count < 5 && !choices.contains(where: { $0.lowercased() == word.lowercased() }) {
            choices.append(word)
        }
        guard choices.count >= 3 else { return nil }
        choices = shuffled.filter { w in choices.contains(w) }.reduce(into: [String]()) { acc, w in if !acc.contains(w) { acc.append(w) } }
        let question = "주어진 낱말을 모두 써서 바르게 배열할 때, \(k + 1)번째에 오는 낱말은?\n( " + shuffled.joined(separator: " / ") + " )"
        return (question, choices, answer)
    }

    /// "어법상 바른 문장은?" · "어법상 틀린 문장은?" (단원 안의 맞는 문장·틀린 문장으로)
    static func composites(_ list: [GrammarUnit]) -> [Problem] {
        let items = list.flatMap(\.items)
        var rightPool: [String] = [], wrongPool: [String] = []
        for item in items {
            for s in correctSentences(item) where !rightPool.contains(s) { rightPool.append(s) }
            for s in wrongSentences(item) where !wrongPool.contains(s) { wrongPool.append(s) }
        }
        guard rightPool.count >= 4, wrongPool.count >= 4 else { return [] }
        let seed = list.map(\.name).joined()
        let rights = seededShuffle(rightPool, seed: seed + "o"), wrongs = seededShuffle(wrongPool, seed: seed + "x")
        var result: [Problem] = []
        for round in 0..<3 {
            // 바른 문장 하나 + 틀린 문장 넷
            let r = rights[round % rights.count]
            let ws = (0..<4).map { wrongs[(round * 4 + $0) % wrongs.count] }
            if Set(ws).count == 4, let p = problem("다음 중 어법상 바른 문장은?", choices: seededShuffle([r] + ws, seed: seed + "\(round)a"), answer: r,
                                                   steps: ["바른 문장: \(r)", "나머지는 모두 어법상 틀려요."]) { result.append(p) }
            // 틀린 문장 하나 + 바른 문장 넷
            let w = wrongs[(round + 7) % wrongs.count]
            let rs = (0..<4).map { rights[(round * 4 + 5 + $0) % rights.count] }
            if Set(rs).count == 4, let p = problem("다음 중 어법상 틀린 문장은?", choices: seededShuffle([w] + rs, seed: seed + "\(round)b"), answer: w,
                                                   steps: ["틀린 문장: \(w)", explainWrong(w, items: items)]) { result.append(p) }
        }
        return result
    }

    /// 틀린 문장의 해설 (그 문장을 만든 문제에서)
    static func explainWrong(_ sentence: String, items: [GrammarItem]) -> String {
        for item in items where wrongSentences(item).contains(sentence) {
            switch item.kind {
            case .fix: return "'\(item.wrong.first ?? "")' → '\(item.answer)'. \(item.note)"
            case .blank, .transform: return "바른 표현은 '\(item.answer)'. \(item.note)"
            default: return item.note
            }
        }
        return "나머지는 모두 어법상 맞아요."
    }

    // MARK: - 고르기 (종류를 섞어서)

    static func pick<T>(_ pool: [T], count: Int, key: (T) -> String) -> [T] {
        var groups: [String: [T]] = [:]
        var order: [String] = []
        for item in pool.shuffled() {
            let k = key(item)
            if groups[k] == nil { order.append(k) }
            groups[k, default: []].append(item)
        }
        order.shuffle()
        var result: [T] = []
        while result.count < count {
            var added = false
            for k in order where result.count < count {
                if var g = groups[k], !g.isEmpty { result.append(g.removeFirst()); groups[k] = g; added = true }
            }
            if !added { break }
        }
        return result
    }

    static func pickCloze(_ list: [GrammarUnit], count: Int) -> [ClozeItem] {
        pick(clozeItems(list), count: count) { $0.sentence.contains("고치면?") ? "fix" : ($0.sentence.contains("\n→") ? "transform" : "blank") }
    }

    static func pickOX(_ list: [GrammarUnit], count: Int) -> [OXItem] {
        pick(oxItems(list), count: count) { $0.isTrue ? "o" : "x" }
    }

    static func pickProblems(_ list: [GrammarUnit], count: Int) -> [Problem] {
        pick(taggedProblems(list), count: count) { $0.tag }.map(\.problem)
    }

    // MARK: - 모의고사 문제 (PracticeItem)

    /// 축약형도 같은 답으로 (모의고사 채점은 글자 비교라서)
    static func contractionVariants(_ text: String) -> [String] {
        let pairs = [("don't", "do not"), ("doesn't", "does not"), ("didn't", "did not"), ("isn't", "is not"), ("aren't", "are not"),
                     ("wasn't", "was not"), ("weren't", "were not"), ("won't", "will not"), ("can't", "cannot"), ("haven't", "have not"),
                     ("hasn't", "has not"), ("hadn't", "had not"), ("shouldn't", "should not"), ("mustn't", "must not"), ("couldn't", "could not"),
                     ("wouldn't", "would not"), ("I'm", "I am"), ("it's", "it is"), ("It's", "It is")]
        var result: [String] = []
        for (short, long) in pairs {
            if text.contains(short) { result.append(text.replacingOccurrences(of: short, with: long)) }
            if text.contains(long) { result.append(text.replacingOccurrences(of: long, with: short)) }
        }
        return result
    }

    /// 영어 답 비교 글: 소문자 · 축약형 풀기(don't = do not) · 글자와 아포스트로피만
    static func apostropheKey(_ s: String) -> String {
        var t = " " + s.lowercased().replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "‘", with: "'") + " "
        let pairs: [(String, String)] = [("won't", "will not"), ("can't", "cannot"), ("n't", " not"), ("'re", " are"), ("'m", " am"),
                                         ("'ll", " will"), ("'ve", " have"), ("can not", "cannot")]
        for (from, to) in pairs { t = t.replacingOccurrences(of: from, with: to) }
        return t.filter { $0.isLetter || $0.isNumber || $0 == "'" }
    }

    /// 모의고사 글자 채점으로 오답과 구별되는지 (its / it's처럼 아포스트로피만 다르면 단답으로 내지 않음)
    static func distinguishable(_ item: GrammarItem) -> Bool {
        let key = DoitGrader.normalizeText(item.answer)
        return !item.wrong.contains { DoitGrader.normalizeText($0) == key }
    }

    static func keys(_ answers: [String]) -> String {
        var all: [String] = []
        for a in answers { for v in [a] + contractionVariants(a) where !all.contains(v) { all.append(v) } }
        return all.joined(separator: "|")
    }

    /// 모의고사·연습에 쓸 문제 (객관식 · 단답 · O/X)
    static func practiceItems(_ list: [GrammarUnit], concept: String) -> [PracticeItem] {
        var result: [PracticeItem] = []
        for p in problems(list) {
            result.append(PracticeItem(level: 3, kind: .multipleChoice, question: p.question, choices: p.choices, answer: "\(p.answerNumber)",
                                       explanation: p.steps, concept: concept))
        }
        for item in list.flatMap(\.items) {
            switch item.kind {
            case .blank:
                guard distinguishable(item) else { continue }
                result.append(PracticeItem(level: 3, kind: .shortAnswer, question: "빈칸에 알맞은 말을 쓰세요.\n\(blankPrompt(item))",
                                           answer: keys([item.answer] + item.alternatives), explanation: ["정답: \(item.answer)", item.note], concept: concept))
            case .transform:
                guard distinguishable(item) else { continue }
                result.append(PracticeItem(level: 4, kind: .shortAnswer, question: "\(item.instruction ?? "문장을 바꿔 쓰세요.") 빈칸에 알맞은 말을 쓰세요.\n\(item.from ?? "")\n→ \(display(item.text))",
                                           answer: keys([item.answer] + item.alternatives), explanation: ["정답: \(item.answer)", item.note], concept: concept))
            case .fix:
                guard let part = item.wrong.first, let right = corrected(item) else { continue }
                result.append(PracticeItem(level: 4, kind: .shortAnswer, question: "어법상 틀린 부분을 찾아 바르게 고쳐 쓰세요. (고친 표현만)\n\(item.text)",
                                           answer: keys([item.answer] + item.alternatives + ["\(part) → \(item.answer)", right]),
                                           explanation: ["'\(part)' → '\(item.answer)'", item.note], concept: concept))
            case .order:
                result.append(PracticeItem(level: 4, kind: .shortAnswer, question: "주어진 낱말을 모두 써서 바르게 배열하세요.\n( " + scrambled(item).joined(separator: " / ") + " )",
                                           answer: keys([item.text]), explanation: ["바른 문장: \(item.text)", item.note], concept: concept))
            default: continue
            }
        }
        for ox in oxItems(list) {
            result.append(PracticeItem(level: 2, kind: .multipleChoice, question: DoitMockExam.prompt(ox: ox.statement), choices: ["O", "X"],
                                       answer: ox.isTrue ? "1" : "2", explanation: [ox.explanation], concept: concept))
        }
        return result
    }

    /// 모의고사 한 문제: slot에 따라 객관식 → 단답 → O/X 순서로 (이미 낸 문제는 빼고)
    static func practice(for units: [GrammarUnit], concept: String, slot: Int, avoid: Set<String>) -> PracticeItem? {
        let all = practiceItems(units, concept: concept).filter { !avoid.contains(DoitPractice.questionKey($0.question)) }
        let choice = all.filter { $0.kind == .multipleChoice && $0.choices.count > 2 }
        let short = all.filter { $0.kind == .shortAnswer }
        let ox = all.filter { $0.kind == .multipleChoice && $0.choices.count == 2 }
        let order: [[PracticeItem]] = slot % 3 == 0 ? [choice, short, ox] : slot % 3 == 1 ? [short, choice, ox] : [ox, choice, short]
        for group in order { if let item = group.randomElement() { return item } }
        return nil
    }

    /// 모의고사 출처(과목·단원·개념 글)에 맞는 문법 단원
    static func units(forSource subject: String, unit: String, concept: String) -> [GrammarUnit] {
        let own = units(subjectName: subject, unit: unit)
        if !own.isEmpty { return own }
        for text in [unit, concept] where !text.isEmpty {
            let found = find(text)
            if !found.isEmpty { return found }
        }
        return []
    }
}

// MARK: - AI 학습 연결

extension DoitStudy {
    /// 문법 단원이면 검증된 문법 자료로 만든 묶음 (모델 없이)
    static func grammarPack(scope: StudyScope) -> StudyPack? {
        let list = DoitGrammar.units(for: scope)
        guard !list.isEmpty else { return nil }
        let materials = list.map {
            DoitStudyMaterial(kind: .curriculum, title: $0.name, names: [$0.name] + $0.aliases, body: $0.summary, source: DoitGrammar.source)
        }
        return StudyPack(scope: scope, materials: materials, basis: DoitStudyCheck.Basis(materials: materials, scope: scope),
                         concept: DoitGrammar.concept(list, scope: scope), madeByModel: false)
    }

    /// 빈칸 답 맞는지: 영어 답은 철자까지 정확히 (대소문자·축약형만 봐줌), 그 밖에는 단어 시험 채점
    static func clozeMatches(_ input: String, answer: String) -> Bool {
        let keys = answer.components(separatedBy: " / ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !keys.isEmpty, keys.allSatisfy(DoitGrader.isEnglishAnswer) {
            // 아포스트로피도 답이에요 (its ↔ it's, Lets ↔ Let's): 축약형만 풀어서 비교
            let mine = DoitGrammar.apostropheKey(input)
            return keys.contains { DoitGrammar.apostropheKey($0) == mine }
        }
        return AnswerChecker.checkMeaning(input, answer: answer)
    }
}

// MARK: - 검색 목록 연결

extension DoitGrammar {
    /// 교육과정 단원 목록에 문법 단원을 더함 (같은 이름 단원이 있으면 다른 이름만 더하고, 없으면 그 학교급 영어 끝에)
    static func extendCatalog(_ list: [DoitStudy.CatalogUnit]) -> [DoitStudy.CatalogUnit] {
        var result = list
        for g in units {
            if let index = result.firstIndex(where: { $0.subjectName == g.subjectName && $0.unit == g.name }) {
                let old = result[index]
                let extra = g.aliases.filter { a in !old.aliases.contains(a) }
                result[index] = DoitStudy.CatalogUnit(subjectName: old.subjectName, subject: old.subject, level: old.level, chapter: old.chapter,
                                                      unit: old.unit, sources: old.sources, usesMathEngine: old.usesMathEngine,
                                                      aliases: old.aliases + extra, terms: old.terms)
            } else {
                let item = DoitStudy.CatalogUnit(subjectName: g.subjectName, subject: "영어", level: g.level, chapter: g.subjectName, unit: g.name,
                                                 sources: [.init(level: g.level, unit: g.name)], usesMathEngine: false, aliases: g.aliases, terms: [])
                let at = (result.lastIndex { $0.subjectName == g.subjectName }).map { $0 + 1 } ?? result.count
                result.insert(item, at: at)
            }
        }
        return result
    }

    /// 학교급 영어 단원 목록에 없는 문법 단원 이름
    static func extraUnitNames(level: SchoolLevel, existing: [String]) -> [String] {
        units.filter { $0.level == level && !existing.contains($0.name) }.map(\.name)
    }

    /// 문법 단원인지 (목록 검색에서 "영어 문법"으로도 찾게)
    static func isGrammarUnit(subjectName: String, unit: String) -> Bool {
        !units(subjectName: subjectName, unit: unit).isEmpty
    }

    /// "영어 문법", "영문법"처럼 문법 전체를 찾을 때 고를 단원들
    static func overview(level: SchoolLevel?) -> [GrammarUnit] {
        let list = units.filter { level == nil || $0.level == level }
        return list.isEmpty ? units : list
    }
}
