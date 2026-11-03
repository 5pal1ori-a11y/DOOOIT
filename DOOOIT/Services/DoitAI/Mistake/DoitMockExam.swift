import Foundation

/// AI 모의고사: 내 취약 개념으로 10문제
/// - 문제는 검증된 생성기로만 만듦: 수학 계산은 MathProblems(풀이 엔진으로 정답 다시 확인),
///   개념 문제는 교육과정 사전으로 만든 O/X · 빈칸 · 객관식(DoitStudyCheck 검증)
/// - 모델이 쓴 글을 정답으로 쓰지 않고, 인터넷도 쓰지 않아요
/// - 문제마다 정답을 채점기에 넣어 "정답"이 나오는지 한 번 더 확인 (채점할 수 없는 문제는 빼요)
struct MockExamSource: Equatable {
    /// 취약 개념 키 (과목|단원|개념) · 최근 단원이면 빈칸
    var key: String = ""
    /// 저장된 과목 글 ("공통수학1", "중학교 수학", "영어" …)
    var subject: String
    var unit: String
    var concept: String = ""
    /// 이 개념에서 틀린 문제 글 (있으면 같은 유형으로)
    var problem: String = ""
    var mastery: Double = 0.5
    var wrongCount: Int = 0

    var category: NoteSubject { NoteSubject.from(subject) }
}

struct MockExamQuestion: Identifiable, Codable, Equatable {
    var id = UUID()
    var item: PracticeItem
    var sourceKey: String
    var subject: String
    var unit: String
    var concept: String

    var isChoice: Bool { !item.choices.isEmpty }
}

struct MockExam: Equatable {
    var questions: [MockExamQuestion]
    /// 취약 개념이 적어서 최근 단원 · 교육과정 단원을 섞었는지
    var usedFallback: Bool
}

enum DoitMockExam {
    static let size = 10
    /// 추천 시간 (분)
    static let minutes = 15
    /// QuizRecord.step 에 적는 이름
    static let step = "mock"
    /// 취약 개념이 이보다 적으면 최근 단원도 섞음
    static let minWeak = 3

    // MARK: 범위

    /// 고를 수 있는 과목 (취약 개념에 있는 과목만, 수학·영어·국어·과학·사회 순)
    static func subjects(in sources: [MockExamSource]) -> [NoteSubject] {
        let found = Set(sources.map(\.category))
        return NoteSubject.allCases.filter { $0 != .other && found.contains($0) }
    }

    /// 약한 순서: 숙련도 낮은 것 → 오답 많은 것
    static func ordered(_ sources: [MockExamSource]) -> [MockExamSource] {
        sources.sorted { ($0.mastery, -$0.wrongCount) < ($1.mastery, -$1.wrongCount) }
    }

    /// 취약 개념이 없을 때 쓰는 교육과정 단원 (고1 공통과목)
    static func curriculumSources(scope: NoteSubject?) -> [MockExamSource] {
        var list: [MockExamSource] = []
        for common in DoitStudy.commonSubjects {
            let category = NoteSubject.from(common.subject)
            if let scope, scope != category { continue }
            for (_, units) in common.chapters {
                for unit in units { list.append(MockExamSource(subject: common.name, unit: unit, concept: unit)) }
            }
        }
        return list
    }

    // MARK: 시험 만들기

    /// 10문제 만들기: 약한 개념부터 번갈아 (계산 · 객관식 · 단답을 섞어서), 모자라면 최근 단원 → 교육과정 단원으로 채움
    static func assemble(weak: [MockExamSource], recent: [MockExamSource] = [], scope: NoteSubject? = nil, count: Int = size) -> MockExam {
        let inScope = { (s: MockExamSource) in scope == nil || s.category == scope }
        let weakList = Array(ordered(weak.filter(inScope)).prefix(count))
        let usedFallback = weakList.count < minWeak
        var questions: [MockExamQuestion] = []
        var seen = Set<String>()
        var packs: [String: StudyPack?] = [:]

        func fill(from sources: [MockExamSource], rounds: Int, limit: Int) {
            guard !sources.isEmpty else { return }
            let goal = min(count, questions.count + limit)
            var slot = 0
            var misses = 0
            while questions.count < goal && misses < sources.count * rounds {
                let source = sources[slot % sources.count]
                // 개념마다 시작하는 문제 종류를 다르게, 돌 때마다 다음 종류로
                if let item = item(for: source, slot: slot / sources.count + slot % sources.count, avoid: seen, packs: &packs) {
                    seen.insert(DoitPractice.questionKey(item.question))
                    questions.append(MockExamQuestion(item: item, sourceKey: source.key, subject: source.subject,
                                                      unit: source.unit, concept: source.concept.isEmpty ? source.unit : source.concept))
                    misses = 0
                } else {
                    misses += 1
                }
                slot += 1
            }
        }

        // 취약 개념이 적으면 개념마다 3문제까지만 내고 나머지는 최근 단원 · 교육과정 단원으로
        fill(from: weakList, rounds: 3, limit: usedFallback ? weakList.count * 3 : count)
        if questions.count < count {
            let recentList = recent.filter(inScope).filter { r in !weakList.contains { $0.subject == r.subject && $0.unit == r.unit } }
            fill(from: Array(recentList.prefix(6)), rounds: 2, limit: count)
        }
        if questions.count < count {
            fill(from: Array(curriculumSources(scope: scope).shuffled().prefix(8)), rounds: 2, limit: count)
        }
        return MockExam(questions: questions, usedFallback: usedFallback || questions.contains { $0.sourceKey.isEmpty })
    }

    /// 한 개념으로 문제 하나 (slot에 따라 계산 · 객관식 · 단답)
    static func item(for source: MockExamSource, slot: Int, avoid: Set<String>, packs: inout [String: StudyPack?]) -> PracticeItem? {
        let concept = source.concept.isEmpty ? source.unit : source.concept
        // 영어 문법 단원: 손으로 쓰고 검증한 문법 문제로 (객관식 · 단답 · O/X)
        if source.category == .english {
            let grammar = DoitGrammar.units(forSource: source.subject, unit: source.unit, concept: concept)
            if !grammar.isEmpty {
                for _ in 0..<3 {
                    if let item = DoitGrammar.practice(for: grammar, concept: concept, slot: slot, avoid: avoid), verified(item) { return item }
                }
            }
        }
        let pack = rulePack(for: source, cache: &packs)
        var makers: [() -> PracticeItem?] = []
        let calc = { mathItem(for: source, concept: concept, hard: slot % 4 == 3, avoid: avoid) }
        let ox = { pack.flatMap { oxItem(pack: $0, concept: concept, avoid: avoid) } }
        let choice = { pack.flatMap { choiceItem(pack: $0, concept: concept, avoid: avoid) } }
        let cloze = { pack.flatMap { clozeItem(pack: $0, concept: concept, avoid: avoid) } }
        if source.category == .math {
            makers = slot % 3 == 1 ? [ox, choice, calc] : [calc, choice, ox]
        } else {
            switch slot % 3 {
            case 0: makers = [choice, ox, cloze]
            case 1: makers = [cloze, ox, choice]
            default: makers = [ox, choice, cloze]
            }
        }
        for make in makers {
            if let item = make(), verified(item) { return item }
        }
        return nil
    }

    /// 정답을 그대로 넣으면 채점기가 "정답"이라고 하는지 (채점할 수 없는 문제는 내지 않음)
    static func verified(_ item: PracticeItem) -> Bool {
        guard !item.question.isEmpty, !item.answer.isEmpty else { return false }
        if item.kind == .multipleChoice {
            guard item.choices.count >= 2, let n = Int(item.answer), n >= 1, n <= item.choices.count else { return false }
        }
        // 정답이 여럿("goes|go → goes")이면 첫 정답으로 확인
        let first = item.answer.contains("|") ? (DoitGrader.alternatives(item.answer).first ?? item.answer) : item.answer
        return DoitPractice.grade(item, answer: first).verdict == .correct
    }

    // MARK: 문제 종류별

    /// 수학 계산 (단답): 틀린 문제의 유형 → 개념 이름 → 단원 이름 순으로 유형을 찾음
    static func mathTopics(for source: MockExamSource) -> [MathProblems.Topic] {
        guard source.category == .math else { return [] }
        if !source.problem.isEmpty, let kind = MathSolver.solve(source.problem)?.kind {
            let topics = DoitPractice.appliedTopics(for: kind, level: source.subject.contains("중학교") ? .middle : .high)
            if let main = MathProblems.topic(for: kind) { return [main] + topics.filter { $0 != main } }
            if !topics.isEmpty { return topics }
        }
        var topics = MathProblems.topic(for: source.concept) ?? MathProblems.topic(for: source.unit) ?? []
        if source.subject.contains("중학교") {
            let allowed: Set<MathProblems.Topic> = [.linear, .quadraticEquation, .quadraticFunction, .expand, .factor, .system, .inequality, .statistics, .numberTheory, .percent]
            topics = topics.filter { allowed.contains($0) }
        }
        return topics
    }

    static func mathItem(for source: MockExamSource, concept: String, hard: Bool, avoid: Set<String>) -> PracticeItem? {
        let topics = mathTopics(for: source)
        guard !topics.isEmpty else { return nil }
        for attempt in 0..<8 {
            let topic = topics[attempt % topics.count]
            let problem = MathProblems.make(topic: topic, hard: hard)
            guard !avoid.contains(DoitPractice.questionKey(problem.question)),
                  DoitStudy.mathAnswerConsistent(problem, topic: topic), !problem.finalAnswer.isEmpty else { continue }
            return PracticeItem(level: hard ? 4 : 3, kind: .math, question: problem.question, answer: problem.finalAnswer,
                                explanation: problem.steps, concept: concept)
        }
        return nil
    }

    static func oxItem(pack: StudyPack, concept: String, avoid: Set<String>) -> PracticeItem? {
        for item in DoitStudy.ruleOX(pack: pack, count: 8).shuffled() where !avoid.contains(DoitPractice.questionKey(prompt(ox: item.statement))) {
            return PracticeItem(level: 2, kind: .multipleChoice, question: prompt(ox: item.statement), choices: ["O", "X"],
                                answer: item.isTrue ? "1" : "2", explanation: [item.explanation], concept: concept)
        }
        return nil
    }

    static func clozeItem(pack: StudyPack, concept: String, avoid: Set<String>) -> PracticeItem? {
        for item in DoitStudy.ruleCloze(pack: pack, count: 8).shuffled() {
            let question = "빈칸에 알맞은 말을 쓰세요.\n\(item.sentence)"
            guard !avoid.contains(DoitPractice.questionKey(question)) else { continue }
            return PracticeItem(level: 3, kind: .shortAnswer, question: question, answer: item.answer,
                                explanation: ["정답: \(item.answer)"], concept: concept)
        }
        return nil
    }

    /// 개념 객관식 ("다음 설명에 해당하는 개념은?" · "옳지 않은 것은?")
    static func choiceItem(pack: StudyPack, concept: String, avoid: Set<String>) -> PracticeItem? {
        for problem in DoitStudy.ruleProblems(pack: pack, count: 4, hard: false).shuffled()
        where problem.choices.count >= 3 && Double(problem.finalAnswer) == nil && !avoid.contains(DoitPractice.questionKey(problem.question)) {
            return PracticeItem(level: 3, kind: .multipleChoice, question: problem.question, choices: problem.choices,
                                answer: "\(problem.answerNumber)", explanation: problem.steps, concept: concept)
        }
        return nil
    }

    static func prompt(ox statement: String) -> String { "맞으면 O, 틀리면 X\n\(statement)" }

    /// 교육과정 사전만으로 만든 단원 자료 (모델·인터넷 없이)
    static func rulePack(for source: MockExamSource, cache: inout [String: StudyPack?]) -> StudyPack? {
        let cacheKey = source.subject + "|" + source.unit + "|" + source.concept
        if let saved = cache[cacheKey] { return saved }
        var made: StudyPack?
        var candidates: [(String, String)] = [(source.subject, source.unit)]
        // 단원 이름으로 찾지 못하면 개념 이름으로 교육과정 사전에서 (DoitPractice와 같은 방법)
        let basis = DoitPractice.basis(problem: source.problem, noteUnit: source.unit.isEmpty ? source.concept : source.unit)
        if let subject = basis.unitSubject, let unit = basis.unit { candidates.append((subject, unit)) }
        if !source.concept.isEmpty, source.concept != source.unit {
            let byConcept = DoitPractice.basis(problem: "", noteUnit: source.concept)
            if let subject = byConcept.unitSubject, let unit = byConcept.unit { candidates.append((subject, unit)) }
        }
        for (subject, unit) in candidates where !subject.isEmpty && !unit.isEmpty {
            guard let scope = try? DoitStudy.scope(subject: subject, unit: unit) else { continue }
            let materials = DoitStudy.materials(for: scope)
            guard !materials.isEmpty else { continue }
            made = StudyPack(scope: scope, materials: materials, basis: DoitStudyCheck.Basis(materials: materials, scope: scope),
                             concept: DoitStudy.ruleConcept(scope: scope, materials: materials, booster: true), madeByModel: false)
            break
        }
        cache[cacheKey] = made
        return made
    }

    // MARK: 채점

    static func grade(_ question: MockExamQuestion, answer: String) -> GradeResult {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return GradeResult(verdict: .wrong, score: 0, method: "답 없음", reasons: ["답을 쓰지 않았어요"],
                               answerUsed: question.item.answer, answerSource: "모의고사")
        }
        // 저장된 정답 글을 그대로 넣으면 (정답이 여럿 "goes|go → goes") 첫 정답으로
        let given = trimmed == question.item.answer && trimmed.contains("|") ? (DoitGrader.alternatives(trimmed).first ?? trimmed) : trimmed
        return DoitPractice.grade(question.item, answer: given)
    }

    /// 맞음 여부 (확실히 정답일 때만 맞음 — 확인 필요·부분 정답은 틀림으로 셈)
    static func isCorrect(_ question: MockExamQuestion, answer: String) -> Bool {
        grade(question, answer: answer).verdict == .correct
    }

    /// 단원별로 묶은 점수 (풀이 기록 저장용)
    struct Group: Equatable {
        var subject: String
        var unit: String
        var correct: Int
        var total: Int
    }

    static func groups(_ questions: [MockExamQuestion], results: [Bool]) -> [Group] {
        var list: [Group] = []
        for (question, ok) in zip(questions, results) {
            let unit = question.unit.isEmpty ? question.concept : question.unit
            let subject = NoteSubject.from(question.subject).rawValue
            if let index = list.firstIndex(where: { $0.subject == subject && $0.unit == unit }) {
                list[index].total += 1
                if ok { list[index].correct += 1 }
            } else {
                list.append(Group(subject: subject, unit: unit, correct: ok ? 1 : 0, total: 1))
            }
        }
        return list
    }

    /// 정답을 보기 좋게 ("2" → "② X")
    static func answerText(_ item: PracticeItem) -> String {
        if !item.choices.isEmpty, let n = Int(item.answer), n >= 1, n <= item.choices.count {
            let marks = ["①", "②", "③", "④", "⑤", "⑥"]
            return (n <= marks.count ? marks[n - 1] + " " : "\(n)번 ") + item.choices[n - 1]
        }
        // 같이 인정하는 답이 있으면 대표 답만 ("goes|does go" → "goes")
        if item.answer.contains("|") { return DoitGrader.alternatives(item.answer).first ?? item.answer }
        return item.answer
    }

    /// 점수에 맞는 짧은 한마디
    static func cheer(correct: Int, total: Int) -> String {
        guard total > 0 else { return "" }
        let rate = Double(correct) / Double(total)
        if correct == total { return "만점! 완벽해요" }
        if rate >= 0.8 { return "거의 다 맞았어요" }
        if rate >= 0.5 { return "틀린 문제만 다시 봐요" }
        return "개념부터 다시 봐요"
    }
}
