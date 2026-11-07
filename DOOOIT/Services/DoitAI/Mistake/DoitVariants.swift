import Foundation

/// 기출 유형 · 변형 문제의 주제 하나 (과목 · 학교급 · 단원)
/// 진짜 기출 시험지는 쓰지 않아요. 문제는 모두 모티 엔진이 만든 것이고,
/// 정답은 엔진이 다시 확인한 것만 내요 (확인할 수 없는 주제는 목록에 나오지 않아요).
struct VariantTopic: Identifiable, Hashable {
    enum Subject: String, CaseIterable {
        case math = "수학"
        case english = "영어"
        case science = "과학"
        case social = "사회"
    }

    enum Source: Hashable {
        /// 수학 계산: 문제 생성기 + 풀이 엔진 재확인
        case math([MathProblems.Topic])
        /// 영어 문법 단원: 직접 쓰고 어법 검사한 문제
        case grammar(subjectName: String, unit: String)
        /// 과학 · 사회 개념: 교육과정 자료에서 만든 O/X · 빈칸 · 객관식
        case knowledge(subjectName: String, unit: String)
    }

    var subject: Subject
    var level: SchoolLevel
    var title: String
    /// 작은 글씨 (대단원 · 학년)
    var detail: String
    var source: Source

    var id: String {
        switch source {
        case .math(let topics): return "math|\(level.rawValue)|\(topics.map { "\($0)" }.joined(separator: ","))"
        case .grammar(let s, let u): return "grammar|\(s)|\(u)"
        case .knowledge(let s, let u): return "knowledge|\(s)|\(u)"
        }
    }
}

enum DoitVariants {
    /// 한 번에 내는 문제 수
    static let setSize = 5
    /// 문제 하나를 만들 때 시도 횟수
    private static let attempts = 40

    // MARK: - 단계

    /// 단계 수 (수학은 기본 · 심화, 나머지는 기본 · 표준 · 심화)
    static func levelCount(_ topic: VariantTopic) -> Int {
        switch topic.source {
        case .math(let topics): return topics.allSatisfy { hardOK.contains($0) } ? 2 : 1
        default: return 3
        }
    }

    static func levelName(_ level: Int) -> String {
        switch level {
        case 1: return "기본"
        case 2: return "표준"
        default: return "심화"
        }
    }

    /// 수학 단계 이름 (기본 · 심화)
    static func levelName(_ level: Int, of topic: VariantTopic) -> String {
        if case .math = topic.source { return level <= 1 ? "기본" : "심화" }
        return levelName(level)
    }

    // MARK: - 수학 주제 (풀이 엔진으로 다시 확인되는 것만)

    private struct MathEntry {
        let topic: MathProblems.Topic
        let title: String
        let chapter: String
        /// 중학교 목록에도 내는지
        let middle: Bool
        let high: Bool
    }

    /// 생성기 정답을 풀이 엔진이 독립적으로 다시 풀어 맞춘 주제만 (테스트가 매번 확인).
    /// 빠진 주제: 경우의 수 기본(합·곱의 법칙), 행렬, 명제, 역함수, 유리함수, 무리함수 (풀이 엔진이 같은 값을 못 내서 확인 불가)
    private static let mathEntries: [MathEntry] = [
        MathEntry(topic: .linear, title: "일차방정식", chapter: "방정식", middle: true, high: false),
        MathEntry(topic: .inequality, title: "일차부등식", chapter: "부등식", middle: true, high: true),
        MathEntry(topic: .system, title: "연립방정식", chapter: "방정식", middle: true, high: true),
        MathEntry(topic: .expand, title: "다항식의 전개", chapter: "다항식", middle: true, high: true),
        MathEntry(topic: .factor, title: "인수분해", chapter: "다항식", middle: true, high: true),
        MathEntry(topic: .quadraticEquation, title: "이차방정식", chapter: "방정식", middle: true, high: true),
        MathEntry(topic: .quadraticFunction, title: "이차함수", chapter: "함수", middle: true, high: true),
        MathEntry(topic: .statistics, title: "통계", chapter: "통계", middle: true, high: true),
        MathEntry(topic: .numberTheory, title: "약수와 배수", chapter: "수와 연산", middle: true, high: false),
        MathEntry(topic: .percent, title: "비율과 백분율", chapter: "수와 연산", middle: true, high: false),
        MathEntry(topic: .geometry, title: "도형의 넓이·부피", chapter: "도형", middle: true, high: false),
        MathEntry(topic: .remainder, title: "나머지정리", chapter: "다항식", middle: false, high: true),
        MathEntry(topic: .complexCalc, title: "복소수", chapter: "방정식", middle: false, high: true),
        MathEntry(topic: .discriminant, title: "판별식", chapter: "방정식", middle: false, high: true),
        MathEntry(topic: .rootRelation, title: "근과 계수의 관계", chapter: "방정식", middle: false, high: true),
        MathEntry(topic: .cubic, title: "삼차방정식", chapter: "방정식", middle: false, high: true),
        MathEntry(topic: .quadInequality, title: "이차부등식", chapter: "부등식", middle: false, high: true),
        MathEntry(topic: .permutation, title: "순열", chapter: "경우의 수", middle: false, high: true),
        MathEntry(topic: .combination, title: "조합", chapter: "경우의 수", middle: false, high: true),
        MathEntry(topic: .distance, title: "두 점 사이의 거리", chapter: "도형의 방정식", middle: false, high: true),
        MathEntry(topic: .internalDivision, title: "선분의 내분점", chapter: "도형의 방정식", middle: false, high: true),
        MathEntry(topic: .lines, title: "직선의 방정식", chapter: "도형의 방정식", middle: false, high: true),
        MathEntry(topic: .circle, title: "원의 방정식", chapter: "도형의 방정식", middle: false, high: true),
        MathEntry(topic: .translation, title: "도형의 이동", chapter: "도형의 방정식", middle: false, high: true),
        MathEntry(topic: .sets, title: "집합", chapter: "집합과 명제", middle: false, high: true),
        MathEntry(topic: .amgm, title: "절대부등식", chapter: "집합과 명제", middle: false, high: true),
        MathEntry(topic: .composite, title: "합성함수", chapter: "함수", middle: false, high: true),
        MathEntry(topic: .sequence, title: "수열", chapter: "수열", middle: false, high: true),
        MathEntry(topic: .derivative, title: "미분", chapter: "미적분", middle: false, high: true),
        MathEntry(topic: .integral, title: "적분", chapter: "미적분", middle: false, high: true)
    ]

    /// 심화(hard) 문제도 풀이 엔진이 확인하는 주제 (인수분해 심화 · 복소수 심화는 확인할 수 없어 뺌)
    private static let hardOK: Set<MathProblems.Topic> = {
        var all = Set(mathEntries.map(\.topic))
        all.subtract([.factor, .complexCalc])
        return all
    }()

    /// 수학 주제 목록 (학교급별)
    static func mathTopics(level: SchoolLevel) -> [VariantTopic] {
        mathEntries.compactMap { entry in
            guard level == .middle ? entry.middle : (level == .high ? entry.high : false) else { return nil }
            return VariantTopic(subject: .math, level: level, title: entry.title, detail: entry.chapter, source: .math([entry.topic]))
        }
    }

    // MARK: - 주제 목록 (과목 · 학교급)

    private static let lock = NSLock()
    private static var poolCache: [String: [PracticeItem]] = [:]
    private static var listCache: [String: [VariantTopic]] = [:]

    /// 고를 수 있는 주제 (문제를 5개 이상 만들 수 있는 것만)
    static func topics(subject: VariantTopic.Subject, level: SchoolLevel) -> [VariantTopic] {
        let key = "\(subject.rawValue)|\(level.rawValue)"
        lock.lock()
        let cached = listCache[key]
        lock.unlock()
        if let cached { return cached }
        var list: [VariantTopic]
        switch subject {
        case .math:
            list = mathTopics(level: level)
        case .english:
            list = DoitGrammar.units.filter { $0.level == level }.map { unit in
                VariantTopic(subject: .english, level: level, title: unit.name, detail: gradeLabel(unit.grades, level: level),
                             source: .grammar(subjectName: unit.subjectName, unit: unit.name))
            }
        case .science, .social:
            let name = subject.rawValue
            var seen = Set<String>()
            list = DoitStudy.catalog.compactMap { item in
                guard item.subject == name, item.level == level, !item.usesMathEngine, seen.insert(item.subjectName + "|" + item.unit).inserted else { return nil }
                return VariantTopic(subject: subject, level: level, title: item.unit, detail: item.chapter,
                                    source: .knowledge(subjectName: item.subjectName, unit: item.unit))
            }
        }
        list = list.filter(isOffered)
        lock.lock()
        listCache[key] = list
        lock.unlock()
        return list
    }

    /// "중2-1" 같은 학년 표시 (여러 학년이면 첫째와 마지막)
    private static func gradeLabel(_ grades: [Int], level: SchoolLevel) -> String {
        guard let first = grades.min(), let last = grades.max() else { return level.rawValue }
        let prefix = level == .elementary ? "초" : level == .middle ? "중" : "고"
        func one(_ g: Int) -> String { g % 10 == 0 ? "\(prefix)\(g / 10)" : "\(prefix)\(g / 10)-\(g % 10)" }
        return first == last ? one(first) : "\(one(first)) ~ \(one(last))"
    }

    /// 이 주제로 문제를 낼 수 있는지 (수학은 확인된 주제, 나머지는 확인된 문제가 5개 이상)
    static func isOffered(_ topic: VariantTopic) -> Bool {
        switch topic.source {
        case .math(let list): return !list.isEmpty && list.allSatisfy { t in mathEntries.contains { $0.topic == t } }
        default: return pool(topic).count >= setSize
        }
    }

    // MARK: - 문제 만들기

    /// 문제 한 개 (정답을 엔진이 다시 확인한 것만, avoid에 있는 문제는 빼고). 못 만들면 nil
    static func makeItem(topic: VariantTopic, level: Int, avoid: Set<String> = []) -> PracticeItem? {
        let level = max(1, min(level, levelCount(topic)))
        guard isOffered(topic) else { return nil }
        switch topic.source {
        case .math(let list):
            for attempt in 0..<attempts {
                let math = list[attempt % list.count]
                guard let item = mathItem(math, title: topic.title, level: level), !avoid.contains(DoitPractice.questionKey(item.question)),
                      verified(item, topic: topic) else { continue }
                return item
            }
            return nil
        default:
            let candidates = pool(topic).filter { !avoid.contains(DoitPractice.questionKey($0.question)) }
            // 고른 단계의 문제부터, 모자라면 가까운 단계
            let sorted = candidates.shuffled().sorted { abs($0.level - level) < abs($1.level - level) }
            return sorted.first
        }
    }

    /// 한 세트 (기본 5개). 서로 다른 문제로, 모자라면 있는 만큼만
    static func makeSet(topic: VariantTopic, level: Int, count: Int = setSize, avoid: Set<String> = []) -> [PracticeItem] {
        var seen = avoid
        var items: [PracticeItem] = []
        let level = max(1, min(level, levelCount(topic)))
        guard isOffered(topic) else { return [] }
        if case .math = topic.source {
            while items.count < count, let item = makeItem(topic: topic, level: level, avoid: seen) {
                seen.insert(DoitPractice.questionKey(item.question))
                items.append(item)
            }
            return items
        }
        // 문제 은행: 고른 단계 → 가까운 단계 순으로 (같은 단계 안에서는 섞어서)
        let candidates = pool(topic).filter { !seen.contains(DoitPractice.questionKey($0.question)) }
        let ordered = candidates.shuffled().sorted { abs($0.level - level) < abs($1.level - level) }
        for item in ordered where items.count < count {
            items.append(item)
        }
        return items
    }

    // MARK: - 수학

    private static func mathItem(_ topic: MathProblems.Topic, title: String, level: Int) -> PracticeItem? {
        let hard = level >= 2 && hardOK.contains(topic)
        let problem = MathProblems.make(topic: topic, hard: hard)
        guard confirmed(problem, topic: topic) else { return nil }
        // 기본 단계는 객관식(보기에 정답이 정확히 한 번), 심화는 단답
        let choices = problem.choices
        let choiceOK = choices.count >= 4 && problem.answerNumber >= 1 && problem.answerNumber <= choices.count
            && choices[problem.answerNumber - 1] == problem.finalAnswer && Set(choices).count == choices.count
        if level <= 1, choiceOK {
            return PracticeItem(level: level, kind: .multipleChoice, question: problem.question, choices: choices,
                                answer: "\(problem.answerNumber)", explanation: problem.steps, concept: title)
        }
        return PracticeItem(level: level, kind: .math, question: problem.question, answer: problem.finalAnswer,
                            explanation: problem.steps, concept: title)
    }

    /// 생성기의 정답을 풀이 엔진이 독립적으로 다시 풀어서 같은지, 풀이 줄에도 같은 답이 있는지
    static func confirmed(_ problem: Problem, topic: MathProblems.Topic) -> Bool {
        let answer = problem.finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !problem.question.isEmpty, !answer.isEmpty, !problem.steps.isEmpty else { return false }
        // 풀이 줄 어딘가에 같은 답 (해설이 답과 어긋난 문제를 거름)
        guard stepsMention(answer, steps: problem.steps) else { return false }
        // 전개 문제("x의 계수는?")는 풀이 엔진이 식 전체를 내므로 그 식에서 계수를 읽어 비교
        if topic == .expand { return expandConfirmed(problem) }
        guard let solved = MathSolver.solve(problem.question) else { return false }
        let mine = values(answer), theirs = values(solved.answer)
        if !mine.isEmpty {
            return !theirs.isEmpty && mine.allSatisfy { m in theirs.contains { abs($0 - m) < 1e-6 } }
        }
        return normalized(answer) == normalized(solved.answer)
    }

    private static func expandConfirmed(_ problem: Problem) -> Bool {
        guard problem.question.contains("x의 계수"), let solved = MathSolver.solve(problem.question),
              let coefficient = coefficientOfX(in: solved.answer), let given = Double(problem.finalAnswer.replacingOccurrences(of: "−", with: "-")) else { return false }
        return abs(coefficient - given) < 1e-6
    }

    /// "2x² − 4x − 21" 에서 x의 계수 (-4)
    static func coefficientOfX(in polynomial: String) -> Double? {
        let text = polynomial.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: " ", with: "")
        guard !text.isEmpty else { return nil }
        var total: Double?
        for m in text.matches(of: #/([+-]?)(\d*)x(²|³|\^\d)?/#) where m.3 == nil {
            let digits = String(m.2)
            let value = digits.isEmpty ? 1 : (Double(digits) ?? 0)
            total = (total ?? 0) + (m.1 == "-" ? -value : value)
        }
        // x 항이 없고 x² 항이 있으면 계수 0 (예: x² − 36)
        return total ?? (text.contains("x²") ? 0 : nil)
    }

    private static func stepsMention(_ answer: String, steps: [String]) -> Bool {
        let joined = steps.joined(separator: " ").replacingOccurrences(of: "−", with: "-")
        let mine = values(answer)
        if mine.isEmpty { return normalized(joined).contains(normalized(answer)) }
        let inSteps = values(joined)
        return mine.allSatisfy { m in inSteps.contains { abs($0 - m) < 1e-6 } }
    }

    /// 글 속 수 (분수 3/2 → 1.5, √는 값으로)
    static func values(_ text: String) -> [Double] {
        var t = text.replacingOccurrences(of: "−", with: "-")
        t = t.replacingOccurrences(of: #"√\(?(\d+)\)?"#, with: "$1", options: .regularExpression)
        var out: [Double] = []
        for m in t.matches(of: #/(-?\d+(?:\.\d+)?)\s*\/\s*(\d+(?:\.\d+)?)/#) {
            if let a = Double(String(m.1)), let b = Double(String(m.2)), b != 0 { out.append(a / b) }
        }
        t = t.replacingOccurrences(of: #"-?\d+(?:\.\d+)?\s*\/\s*\d+(?:\.\d+)?"#, with: " ", options: .regularExpression)
        out += DoitMathTopics.numbers(in: t)
        return out
    }

    private static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "−", with: "-").filter { !$0.isWhitespace && !"'\"".contains($0) }.lowercased()
    }

    // MARK: - 영어 문법 · 과학 · 사회 문제 은행

    /// 단계: 1 = O/X · 객관식, 2 = 빈칸·단답, 3 = 고쳐 쓰기·배열·개념 고르기
    private static func band(_ item: PracticeItem) -> Int {
        if item.kind == .multipleChoice { return item.choices.count == 2 ? 1 : (item.level >= 4 ? 3 : 1) }
        return item.level >= 4 ? 3 : 2
    }

    /// 주제의 검증된 문제 은행 (정답을 넣으면 채점기가 정답으로 보는 것만, 같은 문제는 하나)
    static func pool(_ topic: VariantTopic) -> [PracticeItem] {
        lock.lock()
        let cached = poolCache[topic.id]
        lock.unlock()
        if let cached { return cached }
        var raw: [PracticeItem] = []
        switch topic.source {
        case .math:
            return []
        case .grammar(let subjectName, let unit):
            let list = DoitGrammar.units(subjectName: subjectName, unit: unit)
            raw = list.isEmpty ? [] : DoitGrammar.practiceItems(list, concept: topic.title)
        case .knowledge(let subjectName, let unit):
            raw = knowledgeItems(subjectName: subjectName, unit: unit, concept: topic.title)
        }
        var seen = Set<String>()
        var result: [PracticeItem] = []
        for var item in raw where DoitMockExam.verified(item) && seen.insert(DoitPractice.questionKey(item.question)).inserted {
            item.level = band(item)
            result.append(item)
        }
        lock.lock()
        poolCache[topic.id] = result
        lock.unlock()
        return result
    }

    private static func knowledgeItems(subjectName: String, unit: String, concept: String) -> [PracticeItem] {
        var cache: [String: StudyPack?] = [:]
        let source = MockExamSource(subject: subjectName, unit: unit, concept: concept)
        guard let pack = DoitMockExam.rulePack(for: source, cache: &cache) else { return [] }
        var items: [PracticeItem] = []
        for ox in DoitStudy.ruleOX(pack: pack, count: 24) {
            items.append(PracticeItem(level: 1, kind: .multipleChoice, question: DoitMockExam.prompt(ox: ox.statement), choices: ["O", "X"],
                                      answer: ox.isTrue ? "1" : "2", explanation: [ox.explanation], concept: concept))
        }
        for cloze in DoitStudy.ruleCloze(pack: pack, count: 24) {
            items.append(PracticeItem(level: 2, kind: .shortAnswer, question: "빈칸에 알맞은 말을 쓰세요.\n\(cloze.sentence)", answer: cloze.answer,
                                      explanation: ["정답: \(cloze.answer)"], concept: concept))
        }
        for hard in [false, true] {
            for problem in DoitStudy.ruleProblems(pack: pack, count: 8, hard: hard)
            where problem.choices.count >= 3 && Double(problem.finalAnswer) == nil && problem.answerNumber >= 1 && problem.answerNumber <= problem.choices.count {
                items.append(PracticeItem(level: 4, kind: .multipleChoice, question: problem.question, choices: problem.choices,
                                          answer: "\(problem.answerNumber)", explanation: problem.steps, concept: concept))
            }
        }
        return items
    }

    // MARK: - 확인 · 채점

    /// 문제 하나가 낼 만한지: 정답을 그대로 넣으면 채점기가 정답으로 보고, 오답 하나는 정답으로 보지 않음
    static func verified(_ item: PracticeItem, topic: VariantTopic? = nil) -> Bool {
        guard DoitMockExam.verified(item) else { return false }
        if item.kind == .multipleChoice, let n = Int(item.answer), item.choices.count >= 2 {
            // 다른 보기를 고르면 오답이어야 함
            for other in 1...item.choices.count where other != n {
                if DoitPractice.grade(item, answer: "\(other)").verdict == .correct { return false }
            }
        }
        return true
    }

    /// 채점 (맞음 · 틀림 · 확인 필요)
    static func grade(_ item: PracticeItem, answer: String) -> GradeResult {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return GradeResult(verdict: .wrong, score: 0, method: "답 없음", reasons: ["답을 쓰지 않았어요"], answerUsed: item.answer, answerSource: "변형 문제")
        }
        return DoitPractice.grade(item, answer: trimmed)
    }

    /// 정답을 보기 좋게 ("2" → "② X")
    static func answerText(_ item: PracticeItem) -> String { DoitMockExam.answerText(item) }

    // MARK: - 오답노트로

    /// 오답노트에 담을 문제 글 (객관식은 보기를 ①②③ 로 붙임)
    static func noteText(_ item: PracticeItem) -> String {
        guard !item.choices.isEmpty else { return item.question }
        let marks = ["①", "②", "③", "④", "⑤"]
        return item.question + "\n" + item.choices.prefix(5).enumerated().map { "\(marks[$0.offset]) \($0.element)" }.joined(separator: " ")
    }

    // MARK: - AI 학습 단원에서 이어 가기

    /// AI 학습 단원(과목 이름 + 단원 이름, 교육과정 그대로)에서 변형 문제를 낼 수 있는 주제 (엔진이 확인한 것만, 없으면 nil)
    /// - 수학: 단원에 맞는 계산 유형 중 풀이 엔진이 다시 확인하는 것만 (중학교는 중학교 유형만)
    /// - 영어: 문법 단원 / 과학 · 사회: 교육과정 자료에서 만든 확인된 문제 5개 이상
    static func topic(subjectName: String, unit: String) -> VariantTopic? {
        guard let item = DoitStudy.catalog.first(where: { $0.subjectName == subjectName && $0.unit == unit }) else { return nil }
        let level = item.level
        switch item.subject {
        case "수학":
            guard level == .middle || level == .high else { return nil }
            let scope = DoitStudy.scope(for: item)
            let allowed = Set(mathEntries.filter { level == .middle ? $0.middle : $0.high }.map(\.topic))
            let list = (DoitStudy.mathTopics(for: scope) ?? []).filter { allowed.contains($0) }
            var unique: [MathProblems.Topic] = []
            for t in list where !unique.contains(t) { unique.append(t) }
            guard !unique.isEmpty else { return nil }
            let topic = VariantTopic(subject: .math, level: level, title: unit, detail: item.chapter, source: .math(unique))
            return isOffered(topic) ? topic : nil
        case "영어":
            guard let grammar = DoitGrammar.units(subjectName: subjectName, unit: unit).first else { return nil }
            let topic = VariantTopic(subject: .english, level: grammar.level, title: unit, detail: gradeLabel(grammar.grades, level: grammar.level),
                                     source: .grammar(subjectName: grammar.subjectName, unit: grammar.name))
            return isOffered(topic) ? topic : nil
        case "과학", "사회":
            guard !item.usesMathEngine, let subject = VariantTopic.Subject(rawValue: item.subject) else { return nil }
            let topic = VariantTopic(subject: subject, level: level, title: unit, detail: item.chapter, source: .knowledge(subjectName: item.subjectName, unit: unit))
            return isOffered(topic) ? topic : nil
        default:
            return nil
        }
    }

    // MARK: - 대화에서 이어 가기

    /// 대화 주제(수학 문제 · 개념 이름)에서 변형 문제를 낼 수 있는 주제 (없으면 nil)
    static func topic(forProblem problem: String) -> VariantTopic? {
        guard let kind = MathSolver.kind(of: problem) else { return nil }
        let basis = DoitPractice.basis(problem: problem)
        let level: SchoolLevel = basis.level == .middle ? .middle : .high
        return topic(forMath: kind, level: level)
    }

    static func topic(forMath kind: MathSolver.Kind, level: SchoolLevel) -> VariantTopic? {
        guard let topic = MathProblems.topic(for: kind) else { return nil }
        let order: [SchoolLevel] = level == .middle ? [.middle, .high] : [.high, .middle]
        for lv in order {
            if let found = mathTopics(level: lv).first(where: { if case .math(let l) = $0.source { return l.contains(topic) }; return false }) {
                return found
            }
        }
        return nil
    }

    /// 개념 이름 (예: "현재완료", "광합성")으로 변형 문제를 낼 수 있는 주제
    static func topic(forConcept name: String) -> VariantTopic? {
        // 수학: 주제 이름이 그대로 같을 때 ("이차방정식", "인수분해")
        let key = name.filter { !$0.isWhitespace }
        if let entry = mathEntries.first(where: { $0.title.filter { !$0.isWhitespace } == key }) {
            let kb = DoitKnowledge.entry(named: name)?.level
            let level: SchoolLevel = (kb == .middle && entry.middle) || !entry.high ? .middle : .high
            return mathTopics(level: level).first { if case .math(let list) = $0.source { return list == [entry.topic] }; return false }
        }
        let grammar = DoitGrammar.find(name)
        if let unit = grammar.first {
            let topic = VariantTopic(subject: .english, level: unit.level, title: unit.name, detail: gradeLabel(unit.grades, level: unit.level),
                                     source: .grammar(subjectName: unit.subjectName, unit: unit.name))
            return isOffered(topic) ? topic : nil
        }
        guard let entry = DoitKnowledge.entry(named: name), let level = entry.level, let unit = entry.unit,
              let subject = VariantTopic.Subject(rawValue: entry.subject), subject == .science || subject == .social else { return nil }
        if let item = DoitStudy.catalog.first(where: { $0.subject == entry.subject && $0.level == level && $0.unit == unit && !$0.usesMathEngine }) {
            let topic = VariantTopic(subject: subject, level: level, title: unit, detail: item.chapter, source: .knowledge(subjectName: item.subjectName, unit: unit))
            return isOffered(topic) ? topic : nil
        }
        return nil
    }
}
