import Foundation

/// 유사 문제 단계 학습
/// 1단계 기본 개념 확인 → 2단계 쉬운 유형 → 3단계 비슷한 난이도 → 4단계 응용 → 5단계 최종 복습
/// 맞히면 한 단계 올라가고, 틀리면 개념을 다시 보여준 뒤 한 단계 쉬운 문제를 줘요.
struct PracticeItem: Codable, Equatable, Identifiable {
    var id = UUID()
    var level: Int
    var kind: ProblemKind
    var question: String
    var choices: [String] = []
    var answer: String
    var explanation: [String]
    /// 이 문제로 연습하는 개념
    var concept: String
}

struct PracticeAttempt: Codable, Equatable {
    var level: Int
    var question: String
    var given: String
    var correct: Bool
    var date = Date()
}

struct PracticeLadder: Codable, Equatable {
    var level: Int
    var current: PracticeItem?
    var history: [PracticeAttempt] = []
    var streak = 0
    var finished = false
    /// 틀렸을 때 다시 보여줄 개념 설명
    var reminder: String?
    /// 원래 문제 재도전 기록
    var retries: [PracticeAttempt] = []

    var correctCount: Int { history.filter(\.correct).count }

    static func levelTitle(_ level: Int) -> String {
        switch level {
        case 1: return "1단계 · 기본 개념 확인"
        case 2: return "2단계 · 쉬운 유형 연습"
        case 3: return "3단계 · 비슷한 난이도"
        case 4: return "4단계 · 응용"
        default: return "5단계 · 최종 복습"
        }
    }
}

enum DoitPractice {
    /// 연습의 바탕: 원래 문제의 유형·개념
    struct Basis {
        var problem: String
        var kind: MathSolver.Kind?
        var concept: String
        /// 개념을 다시 설명할 글
        var reminder: String
        /// 개념 문제(1단계)를 만들 교육과정 단원
        var unitSubject: String?
        var unit: String?
        /// 원래 문제의 학교급 (중학교면 고등 유형은 안 냄)
        var level: SchoolLevel?
    }

    static func basis(problem: String, noteUnit: String = "") -> Basis {
        let solved = MathSolver.solve(problem)
        if let solved, let info = DoitMathConceptMap.info(for: solved.kind) {
            let points = DoitMathConcepts.note(for: info.unit)?.points.prefix(2).joined(separator: "\n") ?? ""
            let level: SchoolLevel? = info.subject.hasPrefix("중학교") ? .middle : .high
            return Basis(problem: problem, kind: solved.kind, concept: info.concept,
                         reminder: "💡 \(solved.concept)" + (points.isEmpty ? "" : "\n" + points), unitSubject: info.subject, unit: info.unit, level: level)
        }
        if let solved {
            return Basis(problem: problem, kind: solved.kind, concept: solved.topic, reminder: "💡 \(solved.concept)")
        }
        // 수학이 아닌 문제: 노트의 단원(개념 이름)으로
        let topic = noteUnit.trimmingCharacters(in: .whitespaces)
        if let entry = DoitKnowledge.entry(named: topic) ?? DoitKnowledge.search(topic, limit: 1).first.flatMap({ $0.score >= 0.6 ? $0.entry : nil }) {
            return Basis(problem: problem, kind: nil, concept: entry.title, reminder: "💡 \(entry.title): \(entry.body.components(separatedBy: "예:")[0])",
                         unitSubject: entry.level.map { "\($0.rawValue) \(entry.subject)" }, unit: entry.unit ?? entry.title, level: entry.level)
        }
        return Basis(problem: problem, kind: nil, concept: topic, reminder: "")
    }

    /// 응용(4단계)에 쓰는 같은 개념의 다른 물음
    static func appliedTopics(for kind: MathSolver.Kind, level: SchoolLevel?) -> [MathProblems.Topic] {
        let high = level != .middle
        switch kind {
        case .quadraticEquation: return high ? [.discriminant, .rootRelation] : [.quadraticEquation]
        case .rootRelation: return [.discriminant, .rootRelation]
        case .factor: return [.quadraticEquation]
        case .expression: return [.factor]
        case .remainder: return high ? [.factor, .remainder] : [.remainder]
        case .vertex: return [.quadraticFunction]
        default: return MathProblems.topic(for: kind).map { [$0] } ?? []
        }
    }

    /// 단계에 맞는 새 문제 (원래 문제·이미 푼 문제와 같은 문제는 피하고, 정답은 다시 풀어 확인)
    static func makeItem(level: Int, basis: Basis, avoid: [String]) async -> PracticeItem? {
        if level == 1, let item = await conceptItem(basis: basis, avoid: avoid) { return item }
        guard let kind = basis.kind, let topic = MathProblems.topic(for: kind) else {
            // 수학이 아니면 단계별로 개념 문제 (O/X → 빈칸 → 객관식)
            return await conceptItem(basis: basis, avoid: avoid, level: level)
        }
        let topics: [MathProblems.Topic]
        let hard: Bool
        switch level {
        case 1, 2: topics = [topic]; hard = false
        case 3: topics = [topic]; hard = false
        case 4: topics = appliedTopics(for: kind, level: basis.level); hard = true
        default: topics = [topic] + appliedTopics(for: kind, level: basis.level); hard = true
        }
        let seen = Set((avoid + [basis.problem]).map(questionKey))
        let seenTemplates = Set((avoid + [basis.problem]).map(templateKey))
        // 1차: 원래 문제·앞 단계와 "모양"이 다른 문제 (숫자만 바꾼 문제는 피함)
        // 2차: 그 유형에 다른 모양이 없으면 숫자가 다른 문제라도
        for strict in [true, false] {
            for _ in 0..<10 {
                guard let chosen = topics.randomElement() else { break }
                let problem = MathProblems.make(topic: chosen, hard: hard)
                guard !seen.contains(questionKey(problem.question)), !strict || !seenTemplates.contains(templateKey(problem.question)),
                      DoitStudy.mathAnswerConsistent(problem, topic: chosen) else { continue }
                return PracticeItem(level: level, kind: .math, question: problem.question, answer: problem.finalAnswer,
                                    explanation: problem.steps, concept: basis.concept)
            }
        }
        return nil
    }

    /// 개념 확인 문제: 그 개념의 교육과정 단원 자료로 (O/X·빈칸·객관식)
    static func conceptItem(basis: Basis, avoid: [String], level: Int = 1) async -> PracticeItem? {
        guard let subject = basis.unitSubject, let unit = basis.unit,
              let pack = try? await DoitStudy.pack(subject: subject, unit: unit) else { return nil }
        let seen = Set(avoid.map(questionKey))
        switch level {
        case 1, 2:
            for item in DoitStudy.ruleOX(pack: pack, count: 6).shuffled() where !seen.contains(questionKey(item.statement)) {
                return PracticeItem(level: level, kind: .multipleChoice, question: "다음 문장이 맞으면 O, 틀리면 X를 고르세요.\n\(item.statement)",
                                    choices: ["O", "X"], answer: item.isTrue ? "1" : "2", explanation: [item.explanation], concept: basis.concept)
            }
            fallthrough
        case 3:
            for item in DoitStudy.ruleCloze(pack: pack, count: 6).shuffled() where !seen.contains(questionKey(item.sentence)) {
                return PracticeItem(level: level, kind: .shortAnswer, question: "빈칸에 알맞은 말을 쓰세요.\n\(item.sentence)",
                                    answer: item.answer, explanation: ["정답: \(item.answer)"], concept: basis.concept)
            }
            fallthrough
        default:
            for problem in DoitStudy.ruleProblems(pack: pack, count: 4, hard: level >= 4).shuffled() where !seen.contains(questionKey(problem.question)) {
                return PracticeItem(level: level, kind: problem.choices.count >= 3 && Double(problem.finalAnswer) == nil ? .multipleChoice : .math,
                                    question: problem.question, choices: Double(problem.finalAnswer) == nil ? problem.choices : [],
                                    answer: Double(problem.finalAnswer) == nil ? "\(problem.answerNumber)" : problem.finalAnswer,
                                    explanation: problem.steps, concept: basis.concept)
            }
        }
        return nil
    }

    /// 답 제출: 채점하고 다음 단계로 (맞히면 올라가고, 틀리면 개념을 보여주고 한 단계 내려감)
    static func grade(_ item: PracticeItem, answer: String) -> GradeResult {
        DoitGrader.grade(.init(kind: item.kind, student: answer, answerKey: item.answer, choices: item.choices, problem: item.question))
    }

    static func advance(_ ladder: inout PracticeLadder, item: PracticeItem, answer: String, result: GradeResult, reminder: String) {
        let correct = result.verdict == .correct
        ladder.history.append(PracticeAttempt(level: item.level, question: item.question, given: answer, correct: correct))
        if correct {
            ladder.streak += 1
            ladder.reminder = nil
            if item.level >= 5 { ladder.finished = true } else { ladder.level = item.level + 1 }
        } else {
            ladder.streak = 0
            ladder.reminder = reminder.isEmpty ? nil : reminder
            ladder.level = max(1, item.level - 1)
        }
        ladder.current = nil
    }

    /// 같은 문제인지 비교
    static func questionKey(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }

    /// 문제의 "모양" (숫자와 부호를 지움): 숫자만 바꾼 문제는 모양이 같음
    static func templateKey(_ text: String) -> String {
        DoitGrader.cleanMath(text).replacingOccurrences(of: #"[0-9.+\-−]+"#, with: "#", options: .regularExpression)
    }
}

/// 개념 숙련도: 한 번 맞혔다고 익혔다고 보지 않음
/// - 틀리면 숙련도가 크게 내려가고, 맞히면 단계가 높을수록 더 올라감
/// - "익힘"은 숙련도 0.85 이상 + 3번 연속 정답 + 서로 다른 날 2일 이상 정답 + 4단계 이상을 맞혔을 때만
enum DoitMastery {
    enum State: String, Codable {
        case weak = "취약"
        case practicing = "연습 중"
        case almost = "거의 익힘"
        case mastered = "익힘"
    }

    struct Record: Codable, Equatable {
        var date: Date
        var correct: Bool
        var level: Int
        /// "오답노트", "유사 문제", "재도전"
        var source: String
    }

    static func updated(_ mastery: Double, correct: Bool, level: Int) -> Double {
        if correct {
            let gain = 0.08 + 0.04 * Double(min(max(level, 1), 5))
            return min(1, mastery + (1 - mastery) * gain)
        }
        return max(0, mastery * 0.6)
    }

    static func state(mastery: Double, records: [Record], wrongCount: Int) -> State {
        let streak = records.reversed().prefix { $0.correct }.count
        let correctDays = Set(records.filter(\.correct).map { Calendar.current.startOfDay(for: $0.date) }).count
        let highLevel = records.contains { $0.correct && $0.level >= 4 }
        if mastery >= 0.85 && streak >= 3 && correctDays >= 2 && highLevel { return .mastered }
        if mastery >= 0.65 && streak >= 2 { return .almost }
        if wrongCount >= 2 && mastery < 0.5 || mastery < 0.3 { return .weak }
        return .practicing
    }

    /// 같은 개념에서 오답이 반복되면 취약 개념
    static func isWeak(mastery: Double, wrongCount: Int) -> Bool {
        wrongCount >= 2 && mastery < 0.6 || mastery < 0.3
    }
}
