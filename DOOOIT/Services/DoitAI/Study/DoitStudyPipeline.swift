import Foundation

/// 학습 자료 한 조각 (교육과정 사전의 개념 하나, 수학 엔진의 정리 한 줄, 인터넷 자료 한 편)
struct DoitStudyMaterial: Hashable {
    enum Kind: String { case curriculum, engine, web }
    let kind: Kind
    let title: String
    let names: [String]
    let body: String
    var source: String

    /// 첫 문장 (정의)
    var definition: String { DoitStudy.sentences(of: paragraph).first ?? paragraph }
    /// "예:" 앞부분 (설명)
    var paragraph: String {
        let parts = body.components(separatedBy: "예:")
        return parts[0].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }
    /// "예:" 뒷부분들 (예시)
    var examples: [String] {
        body.components(separatedBy: "예:").dropFirst().map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.count >= 4 }
    }
}

/// 한 단원의 학습 묶음: 범위 → 자료 → 개념 → (이 개념으로) 빈칸·O/X·문제
struct StudyPack {
    let scope: StudyScope
    let materials: [DoitStudyMaterial]
    let basis: DoitStudyCheck.Basis
    var concept: ConceptNote
    /// 개념을 모델이 만들었는지 (아니면 교육과정 자료로 직접 정리)
    var madeByModel: Bool
}

extension DoitStudy {
    enum StudyError: LocalizedError {
        case unclear(String)
        case noMaterial(String)
        case notEnough(String)
        var errorDescription: String? {
            switch self {
            case .unclear(let m), .noMaterial(let m), .notEnough(let m): return m
            }
        }
    }

    /// 모델이 만든 결과를 다시 만들어 볼 최대 횟수 (무한 반복 방지)
    static let maxRetries = 2

    // MARK: - 1~3. 입력 확인 → 범위 → 자료 검색

    static func scope(subject: String, unit: String) throws -> StudyScope {
        switch resolve(subject: subject, unit: unit) {
        case .resolved(let scope):
            return scope
        case .ambiguous(let options):
            throw StudyError.unclear("'\(unit)'은(는) 여러 단원으로 해석돼요: " + options.map(\.label).joined(separator: ", ") + ". AI 학습 목록에서 하나를 골라 주세요.")
        case .notFound(let message, let suggestions):
            throw StudyError.noMaterial(message + (suggestions.isEmpty ? "" : " " + suggestions.map(\.label).joined(separator: ", ")))
        }
    }

    /// 범위 안의 자료만 (다른 단원·다른 학교급 자료는 절대 가져오지 않음)
    static func materials(for scope: StudyScope) -> [DoitStudyMaterial] {
        var list: [DoitStudyMaterial] = []
        for ref in scope.sources {
            for entry in DoitKnowledge.entries(inUnit: ref.unit, subject: "\(ref.level.rawValue) \(scope.subject)") {
                list.append(DoitStudyMaterial(kind: .curriculum, title: entry.title, names: entry.names, body: entry.body,
                                              source: "두잇 교육과정 사전 · \(ref.level.rawValue) \(scope.subject) 「\(ref.unit)」"))
            }
        }
        if scope.usesMathEngine, let note = DoitMathConcepts.note(for: scope.unit), note.title.replacingOccurrences(of: " ", with: "") == scope.unit.replacingOccurrences(of: " ", with: "") || scope.unit.contains(note.title) || note.title.contains(scope.unit) {
            for point in note.points {
                let name = point.components(separatedBy: ":").first.map { String($0.prefix(20)) } ?? note.title
                list.append(DoitStudyMaterial(kind: .engine, title: point.contains(":") ? name : note.title, names: point.contains(":") ? [name] : [note.title],
                                              body: point, source: "두잇 수학 개념 정리 「\(note.title)」"))
            }
        }
        // 세부 주제와 맞는 개념을 앞으로
        if let sub = scope.subtopic.map(DoitStudyCheck.norm), !sub.isEmpty {
            list.sort { a, b in
                let x = DoitStudyCheck.norm(a.title + a.body).contains(sub), y = DoitStudyCheck.norm(b.title + b.body).contains(sub)
                return x && !y
            }
        }
        return list
    }

    // MARK: - 4~6. 개념 · 상세 설명 · 학습 포인트 (자료로 직접 정리)

    static func ruleConcept(scope: StudyScope, materials: [DoitStudyMaterial], booster: Bool) -> ConceptNote {
        let limit = booster ? 4 : 8
        let used = Array(materials.prefix(limit))
        var points: [String] = []
        var details: [String] = []
        for m in used {
            if m.kind == .engine {
                points.append(m.body)
                continue
            }
            let def = m.definition
            points.append(def.hasPrefix(m.title) ? def : "\(m.title): \(def)")
            details.append("\(m.title) — \(m.paragraph)")
        }
        let titles = used.filter { $0.kind != .engine }.map(\.title)
        var summary = ""
        if let first = used.first {
            let def = first.kind == .engine ? first.body : (first.definition.hasPrefix(first.title) ? first.definition : "\(first.title): \(first.definition)")
            let listed = titles.prefix(4).joined(separator: ", ") + (titles.count > 4 ? " 등" : "")
            summary = titles.count >= 2 ? "이 단원에서는 \(josa(listed, "을", "를")) 배워요. \(def)" : def
        }
        return ConceptNote(title: scope.unit, keyPoints: points, example: ruleExample(scope: scope, materials: materials),
                           summary: summary, details: booster ? [] : details, scope: scope.label,
                           sources: Array(Set(used.map(\.source))).sorted())
    }

    /// 예제: 수학 계산 단원은 직접 만든 문제와 풀이(정답 확인됨), 그 밖에는 자료의 예시
    static func ruleExample(scope: StudyScope, materials: [DoitStudyMaterial]) -> String {
        if scope.subject == "수학", let topics = mathTopics(for: scope), let topic = topics.first {
            let problem = MathProblems.make(topic: topic, hard: false)
            if mathAnswerConsistent(problem, topic: topic) {
                return "예제: \(problem.question)\n풀이: \(problem.steps.joined(separator: " → "))\n답: \(problem.finalAnswer)"
            }
        }
        for m in materials {
            if let example = m.examples.first { return "\(m.title) — 예: \(example)" }
        }
        return ""
    }

    // MARK: - 7~9. 학습 포인트로 문제 · 정답 · 해설 만들기 (같은 묶음의 자료만 씀)

    static func ruleCloze(pack: StudyPack, count: Int) -> [ClozeItem] {
        var items: [ClozeItem] = []
        var usedAnswers = Set<String>()
        let names = pack.materials.filter { $0.kind != .engine }
        for m in names where items.count < count {
            for sentence in [m.definition] + sentences(of: m.paragraph).dropFirst() {
                guard items.count < count, !usedAnswers.contains(m.title) else { break }
                let blanked = blankOut(sentence, names: m.names)
                var text = blanked.text
                if blanked.count == 0 {
                    // 문장에 이름이 없으면 "(   ): 정의" 꼴로
                    guard sentence == m.definition else { continue }
                    text = "\(DoitStudyCheck.blank): \(sentence)"
                } else if blanked.count != 1 { continue }
                let item = ClozeItem(sentence: text, answer: m.title)
                if DoitStudyCheck.check(item, basis: pack.basis).isEmpty {
                    items.append(item)
                    usedAnswers.insert(m.title)
                }
            }
        }
        return items
    }

    static func ruleOX(pack: StudyPack, count: Int) -> [OXItem] {
        let concepts = pack.materials.filter { $0.kind != .engine && $0.definition.count >= 10 }
        var items: [OXItem] = []
        for (index, m) in concepts.enumerated() where items.count < count {
            let def = m.definition
            let statement = def.hasPrefix(m.title) ? def : "\(m.title): \(def)"
            if index % 2 == 1, let other = concepts.first(where: { $0.title != m.title && independent(m, $0) }) {
                // 틀린 문장: 이 개념의 설명에 다른 개념 이름을 붙임
                let core = blankOut(def, names: m.names).text.replacingOccurrences(of: DoitStudyCheck.blank, with: other.title)
                let wrong = def.hasPrefix(m.title) ? core : "\(other.title): \(def)"
                let item = OXItem(statement: wrong, isTrue: false,
                                  explanation: "틀린 문장이에요. 이 설명은 '\(m.title)'에 대한 거예요. \(josa("'\(other.title)'", "은", "는")) \(shortDefinition(other))")
                if DoitStudyCheck.check(item, basis: pack.basis).isEmpty { items.append(item); continue }
            }
            let item = OXItem(statement: statement, isTrue: true, explanation: "맞는 문장이에요. \(statement)")
            if DoitStudyCheck.check(item, basis: pack.basis).isEmpty { items.append(item) }
        }
        // 수학 개념 정리(공통수학)만 있는 단원: 정리 문장 그대로 (맞는 문장)
        if items.isEmpty {
            for m in pack.materials where m.kind == .engine && items.count < count {
                let item = OXItem(statement: m.body, isTrue: true, explanation: "맞는 문장이에요. 교과서 핵심 정리예요.")
                if DoitStudyCheck.check(item, basis: pack.basis).isEmpty { items.append(item) }
            }
        }
        return items
    }

    static func ruleProblems(pack: StudyPack, count: Int, hard: Bool) -> [Problem] {
        var items: [Problem] = []
        // 수학 계산 단원: 직접 만든 문제 (학교급에 맞는 유형만, 정답 다시 확인)
        if pack.scope.subject == "수학", let topics = mathTopics(for: pack.scope), !topics.isEmpty {
            var tries = 0
            while items.count < count && tries < count * 4 {
                tries += 1
                let topic = topics[tries % topics.count]
                let problem = MathProblems.make(topic: topic, hard: hard)
                guard mathAnswerConsistent(problem, topic: topic), DoitStudyCheck.check(problem, basis: pack.basis).isEmpty,
                      !items.contains(where: { $0.question == problem.question }) else { continue }
                items.append(problem)
            }
            if items.count >= count { return items }
        }
        // 개념 문제: "다음 설명에 해당하는 개념은?" (보기는 같은 단원 개념만)
        let concepts = pack.materials.filter { $0.kind != .engine && $0.definition.count >= 10 }
        guard concepts.count >= 3 else {
            // 개념이 둘뿐인 단원: "옳지 않은 것은?" (이 단원의 맞는 문장들 + 이름을 바꾼 틀린 문장 하나)
            return items + falseStatementProblems(concepts: concepts, basis: pack.basis, count: count - items.count)
        }
        for m in concepts.shuffled() where items.count < count {
            let cut = blankOut(m.definition, names: m.names)
            guard cut.count <= 1 else { continue }
            let blanked = cut.text
            // 헷갈리지 않게: 문제 글에 이름이 나오는 개념은 오답 보기로 쓰지 않음 (예: "신라는 당과 연합해…"에 '신라')
            let others = concepts.filter { other in
                other.title != m.title && !other.names.contains { $0.count >= 2 && blanked.contains($0) }
            }.shuffled().prefix(4)
            guard others.count >= 2 else { continue }
            let choices = (others.map(\.title) + [m.title]).shuffled()
            guard let index = choices.firstIndex(of: m.title) else { continue }
            let number = index + 1
            var steps = ["설명의 핵심: \(shortDefinition(m))", "정답은 \(number)번 '\(m.title)'이에요."]
            let otherLines = others.prefix(3).map { "\(josa("'\($0.title)'", "은", "는")) \(shortDefinition($0))" }
            if !otherLines.isEmpty { steps.append("다른 보기: " + otherLines.joined(separator: " / ")) }
            let problem = Problem(question: "다음 설명에 해당하는 개념은?\n\(blanked)", choices: choices, answerNumber: number,
                                  steps: steps, finalAnswer: "\(number)번 \(m.title)")
            if DoitStudyCheck.check(problem, basis: pack.basis).isEmpty { items.append(problem) }
        }
        return items
    }

    /// "다음 중 옳지 않은 것은?" — 맞는 보기는 자료 문장 그대로, 틀린 보기는 개념 이름만 바꾼 것
    static func falseStatementProblems(concepts: [DoitStudyMaterial], basis: DoitStudyCheck.Basis, count: Int) -> [Problem] {
        guard concepts.count == 2, count > 0 else { return [] }
        var items: [Problem] = []
        guard independent(concepts[0], concepts[1]) else { return [] }
        for (a, b) in [(concepts[0], concepts[1]), (concepts[1], concepts[0])] where items.count < count {
            // 맞는 문장: 두 개념의 문장들 (최대 4개)
            var truths: [String] = []
            for m in [a, b] {
                for sentence in sentences(of: m.paragraph).prefix(2) {
                    let statement = sentence.hasPrefix(m.title) || m.names.contains(where: { sentence.contains($0) }) ? sentence : "\(m.title): \(sentence)"
                    if statement.count >= 10 && !truths.contains(statement) { truths.append(statement) }
                }
            }
            // 틀린 문장: a의 정의에 b의 이름을 붙임
            let def = a.definition
            let wrong = def.hasPrefix(a.title) ? blankOut(def, names: a.names).text.replacingOccurrences(of: DoitStudyCheck.blank, with: b.title) : "\(b.title): \(def)"
            guard !truths.contains(wrong), truths.count >= 2 else { continue }
            var choices = Array(truths.filter { $0 != def && !$0.hasSuffix(def) }.prefix(3))
            guard choices.count >= 2 else { continue }
            choices.append(wrong)
            choices.shuffle()
            guard let index = choices.firstIndex(of: wrong) else { continue }
            let problem = Problem(question: "다음 중 옳지 않은 것은?", choices: choices, answerNumber: index + 1,
                                  steps: ["\(index + 1)번은 틀렸어요. 이 설명은 '\(a.title)'에 대한 거예요.", "\(josa("'\(b.title)'", "은", "는")) \(shortDefinition(b))",
                                          "나머지 보기는 모두 교과서 내용과 같아요."],
                                  finalAnswer: "\(index + 1)번")
            if DoitStudyCheck.check(problem, basis: basis).isEmpty { items.append(problem) }
        }
        return items
    }

    // MARK: - 수학 문제 생성기 (학교급에 맞는 유형만)

    /// 단원에 맞는 계산 문제 유형. 중학교는 고등 내용(근과 계수의 관계, 판별식, 복소수 등)을 빼요
    static func mathTopics(for scope: StudyScope) -> [MathProblems.Topic]? {
        guard scope.subject == "수학", let topics = MathProblems.topic(for: scope.unit) else { return nil }
        switch scope.level {
        case .elementary:
            return nil
        case .middle:
            let allowed: Set<MathProblems.Topic> = [.linear, .quadraticEquation, .quadraticFunction, .expand, .factor, .system, .inequality, .statistics, .numberTheory, .percent]
            let filtered = topics.filter { allowed.contains($0) }
            return filtered.isEmpty ? nil : filtered
        default:
            return topics
        }
    }

    /// 풀이 엔진으로 다시 풀어서 같은 답이 나오는지 (다시 풀 수 있는 유형만)
    static func mathAnswerConsistent(_ problem: Problem, topic: MathProblems.Topic) -> Bool {
        guard [.linear, .remainder, .derivative].contains(topic), let solved = MathSolver.solve(problem.question),
              let expected = Double(problem.finalAnswer.replacingOccurrences(of: "−", with: "-")) else { return true }
        let numbers = DoitMathTopics.numbers(in: solved.answer)
        return numbers.isEmpty || numbers.contains { abs($0 - expected) < 1e-6 }
    }

    // MARK: - 도우미

    /// 문장 나누기 (끝 표시는 남김)
    static func sentences(of text: String) -> [String] {
        var result: [String] = []
        var current = ""
        let chars = Array(text)
        for (i, ch) in chars.enumerated() {
            current.append(ch)
            let next = i + 1 < chars.count ? chars[i + 1] : " "
            if (ch == "." || ch == "!" || ch == "?") && next == " ", let prev = current.dropLast().last, !prev.isNumber {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty { result.append(rest) }
        return result.filter { $0.count >= 4 }
    }

    /// 개념 이름을 빈칸으로 (이름(별명)처럼 붙어 있으면 한 빈칸으로)
    static func blankOut(_ sentence: String, names: [String]) -> (text: String, count: Int) {
        var text = sentence
        let sorted = names.filter { $0.count >= 2 }.sorted { $0.count > $1.count }
        for a in sorted { for b in sorted where a != b { text = text.replacingOccurrences(of: "\(a)(\(b))", with: DoitStudyCheck.blank) } }
        for name in sorted { text = text.replacingOccurrences(of: name, with: DoitStudyCheck.blank) }
        // 붙어 있는 빈칸 합치기
        text = text.replacingOccurrences(of: #"\(   \)\s*\(\(   \)\)"#, with: DoitStudyCheck.blank, options: .regularExpression)
        text = text.replacingOccurrences(of: #"(\(   \)\s*){2,}"#, with: DoitStudyCheck.blank + " ", options: .regularExpression)
        let count = text.components(separatedBy: DoitStudyCheck.blank).count - 1
        return (text.trimmingCharacters(in: .whitespaces), count)
    }

    /// 두 개념이 서로의 설명에 나오지 않는지 (이름을 바꾼 틀린 문장이 우연히 맞는 말이 되지 않게)
    /// 예: '광고'의 설명에 '매체'가 나오면 "광고는 정보를 전달하는 수단"이 맞는 말이 될 수 있어서 쓰지 않음
    static func independent(_ a: DoitStudyMaterial, _ b: DoitStudyMaterial) -> Bool {
        let aText = DoitStudyCheck.norm(a.body), bText = DoitStudyCheck.norm(b.body)
        let aNames = a.names.map(DoitStudyCheck.norm).filter { $0.count >= 2 }, bNames = b.names.map(DoitStudyCheck.norm).filter { $0.count >= 2 }
        return !aNames.contains(where: { bText.contains($0) }) && !bNames.contains(where: { aText.contains($0) })
            && !aNames.contains(where: { a in bNames.contains { $0.contains(a) || a.contains($0) } })
    }

    /// 받침에 맞는 조사 ("원의 넓이를", "논리적 오류를", "세포막을"). 한글로 끝나지 않으면 "을(를)"
    static func josa(_ word: String, _ withFinal: String, _ withoutFinal: String) -> String {
        let core = word.trimmingCharacters(in: CharacterSet(charactersIn: "'\" "))
        guard let last = core.unicodeScalars.last, (0xAC00...0xD7A3).contains(last.value) else {
            return word + "\(withFinal)(\(withoutFinal))"
        }
        return word + ((last.value - 0xAC00) % 28 == 0 ? withoutFinal : withFinal)
    }

    static func shortDefinition(_ m: DoitStudyMaterial) -> String {
        DoitMemory.trimmed(m.definition, max: 70)
    }
}
