import Foundation
import SwiftData
import SwiftUI

// MARK: - Planner

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly, monthly, yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "반복 안 함"
        case .daily: return "매일"
        case .weekly: return "매주"
        case .monthly: return "매달"
        case .yearly: return "매년"
        }
    }
}

enum PlanKind: String, Codable, CaseIterable, Identifiable {
    case general, study

    var id: String { rawValue }
    var title: String { self == .study ? "공부 플랜" : "일반 플랜" }
    var subtitle: String { self == .study ? "자동 타이머 · 앱 잠금" : "약속 · 할 일 · 알림" }
    var symbol: String { self == .study ? "timer" : "calendar" }
}

@Model
final class PlanCategory {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#6C63FF"
    var symbol: String = "book.fill"
    /// true: 공부 과목(공부 플랜용), false: 일반 카테고리(일반 플랜용)
    var isStudy: Bool = false
    var sortIndex: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \Plan.category)
    var plans: [Plan]? = []

    init(name: String, symbol: String, colorHex: String, isStudy: Bool, sortIndex: Int) {
        self.id = UUID()
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.isStudy = isStudy
        self.sortIndex = sortIndex
    }

    var color: Color { Color(hex: colorHex) }
}

@Model
final class Plan {
    var id: UUID = UUID()
    var title: String = ""
    var note: String = ""
    /// 첫 일정의 날짜 + 시작 시간
    var startDate: Date = Date()
    var durationMinutes: Int = 60
    var isAllDay: Bool = false
    var repeatRaw: String = "none"
    var repeatEnd: Date?
    /// 완료한 날짜 키 목록 (yyyy-MM-dd)
    var completedKeys: [String] = []
    var category: PlanCategory?
    var createdAt: Date = Date()
    /// general: 일반 플랜(알림만), study: 공부 플랜(자동 타이머, 앱 잠금)
    var kindRaw: String = "general"
    /// 공부 플랜: 시작~종료 시간 동안 DOOOIT 외 다른 앱 잠금
    var lockApps: Bool = false
    /// 일반 플랜 알림: -1 없음, 0 정시, N분 전
    var reminderMinutes: Int = 10

    init(title: String, startDate: Date, durationMinutes: Int, isAllDay: Bool = false,
         repeatRule: RepeatRule = .none, repeatEnd: Date? = nil, category: PlanCategory? = nil, note: String = "",
         kind: PlanKind = .general, lockApps: Bool = false, reminderMinutes: Int = 10) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.isAllDay = isAllDay
        self.repeatRaw = repeatRule.rawValue
        self.repeatEnd = repeatEnd
        self.category = category
        self.note = note
        self.createdAt = Date()
        self.kindRaw = kind.rawValue
        self.lockApps = kind == .study && lockApps
        self.reminderMinutes = reminderMinutes
    }

    var kind: PlanKind {
        get { PlanKind(rawValue: kindRaw) ?? .general }
        set { kindRaw = newValue.rawValue }
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRaw) ?? .none }
        set { repeatRaw = newValue.rawValue }
    }

    var color: Color { category?.color ?? Theme.accent }
    var symbol: String { category?.symbol ?? "circle.fill" }
    var isStudy: Bool { kind == .study }

    func occurs(on day: Date) -> Bool {
        let cal = Calendar.current
        let d = cal.startOfDay(for: day)
        let s = cal.startOfDay(for: startDate)
        guard d >= s else { return false }
        if let end = repeatEnd, d > cal.startOfDay(for: end) { return false }

        switch repeatRule {
        case .none:
            return d == s
        case .daily:
            return true
        case .weekly:
            return cal.component(.weekday, from: d) == cal.component(.weekday, from: s)
        case .monthly:
            return cal.component(.day, from: d) == cal.component(.day, from: s)
        case .yearly:
            let a = cal.dateComponents([.month, .day], from: d)
            let b = cal.dateComponents([.month, .day], from: s)
            return a.month == b.month && a.day == b.day
        }
    }

    func start(on day: Date) -> Date {
        isAllDay ? day.startOfDay : day.combined(withTime: startDate)
    }

    func end(on day: Date) -> Date {
        isAllDay ? day.startOfDay.adding(days: 1) : start(on: day).addingTimeInterval(Double(durationMinutes) * 60)
    }

    func isCompleted(on day: Date) -> Bool {
        completedKeys.contains(day.dayKey)
    }

    func toggleCompleted(on day: Date) {
        let key = day.dayKey
        if let idx = completedKeys.firstIndex(of: key) {
            completedKeys.remove(at: idx)
        } else {
            completedKeys.append(key)
        }
    }
}

/// 특정 날짜에 펼쳐진 일정 (반복 일정 포함)
struct PlanOccurrence: Identifiable {
    let plan: Plan
    let day: Date

    var id: String { "\(plan.id.uuidString)_\(day.dayKey)" }
    var start: Date { plan.start(on: day) }
    var end: Date { plan.end(on: day) }
    var isCompleted: Bool { plan.isCompleted(on: day) }

    var timeText: String {
        plan.isAllDay ? "하루 종일" : "\(start.kr("a h:mm")) - \(end.kr("a h:mm"))"
    }
}

extension Sequence where Element == Plan {
    func occurrences(on day: Date) -> [PlanOccurrence] {
        let d = day.startOfDay
        return self
            .filter { $0.occurs(on: d) }
            .map { PlanOccurrence(plan: $0, day: d) }
            .sorted { a, b in
                if a.plan.isAllDay != b.plan.isAllDay { return a.plan.isAllDay }
                return a.start < b.start
            }
    }
}

// MARK: - Study

@Model
final class Word {
    var id: UUID = UUID()
    var term: String = ""
    var meaning: String = ""
    var deck: String = "기본 단어장"
    var createdAt: Date = Date()
    var learnedAt: Date?
    var correctCount: Int = 0
    var wrongCount: Int = 0
    var isStarred: Bool = false
    /// 복습 단계 (0: 아직 안 외움, 1~5: 복습 기다리는 중, 6: 완전히 외움) — WordReview 참고
    var reviewStage: Int = 0
    /// 다음 복습 날 (없으면 복습 일정 없음)
    var nextReviewAt: Date?

    init(term: String, meaning: String, deck: String = "기본 단어장", createdAt: Date = Date()) {
        self.id = UUID()
        self.term = term
        self.meaning = meaning
        self.deck = deck
        self.createdAt = createdAt
    }

    var isLearned: Bool { learnedAt != nil }
    var isDueForReview: Bool { WordReview.isDue(stage: reviewStage, next: nextReviewAt) }
    var isMastered: Bool { reviewStage >= WordReview.mastered }
}

enum NoteStatus: String, CaseIterable, Identifiable {
    case unsolved, wrong, correct

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unsolved: return "미채점"
        case .wrong: return "오답"
        case .correct: return "정답"
        }
    }

    var symbol: String {
        switch self {
        case .unsolved: return "questionmark.circle.fill"
        case .wrong: return "xmark.circle.fill"
        case .correct: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .unsolved: return Palette.warning
        case .wrong: return Palette.danger
        case .correct: return Palette.success
        }
    }
}

struct TextAnnotation: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var x: Double
    var y: Double
    var colorHex: String
}

@Model
final class MathNote {
    var id: UUID = UUID()
    var title: String = ""
    var unit: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    var thumbnailData: Data?
    var recognizedText: String = ""
    var drawingData: Data?
    var annotationsData: Data?
    var correctAnswer: String = ""
    var myAnswer: String = ""
    var statusRaw: String = "unsolved"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// AI 서술형 단계별 풀이 (WrittenSolution JSON)
    var solutionData: Data?
    /// 영역 선택으로 잘라낸 인쇄된 문제 사진 (다시 분석할 때 사용)
    @Attribute(.externalStorage) var problemImageData: Data?
    /// 내가 단계별로 적은 풀이
    var stepAnswersData: Data?
    /// 풀이 과정 채점: 내 풀이 (한 줄에 한 단계)
    var workText: String = ""
    /// 풀이 과정 채점 결과 (DoitWorkChecker.Report JSON)
    var workCheckData: Data?

    // MARK: AI 오답노트 (모두 기본값이 있어 예전 노트도 그대로 열림)
    /// 문제 유형 (ProblemKind). 비어 있으면 자동 판단
    var kindRaw: String = ""
    /// 인식 상태: "legacy"(예전 노트, 확인된 것으로 봄) · "pending"(사용자 확인 전) · "confirmed"
    var recognitionRaw: String = "legacy"
    /// 문제 나누기 결과 (ProblemScan JSON: 본문·수식·선택지·조건·표·불확실한 곳)
    var scanData: Data?
    /// 채점 결과 (GradeResult JSON)
    var gradeData: Data?
    /// 오답 원인 분석 (MistakeAnalysis JSON)
    var analysisData: Data?
    /// 유사 문제 단계 학습 (PracticeLadder JSON)
    var ladderData: Data?
    /// 취약 개념 연결 (WeakConcept.key)
    var conceptKey: String = ""
    /// 과목 (예: 중학교 수학)
    var subject: String = ""

    var stepAnswers: [String] {
        get { stepAnswersData.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
        set { stepAnswersData = try? JSONEncoder().encode(newValue) }
    }

    init(title: String, imageData: Data?, thumbnailData: Data?, recognizedText: String, correctAnswer: String = "") {
        self.id = UUID()
        self.title = title
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.recognizedText = recognizedText
        self.correctAnswer = correctAnswer
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var status: NoteStatus {
        get { NoteStatus(rawValue: statusRaw) ?? .unsolved }
        set { statusRaw = newValue.rawValue }
    }

    var annotations: [TextAnnotation] {
        get {
            guard let annotationsData else { return [] }
            return (try? JSONDecoder().decode([TextAnnotation].self, from: annotationsData)) ?? []
        }
        set { annotationsData = try? JSONEncoder().encode(newValue) }
    }
}

@Model
final class Memo {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var isPinned: Bool = false
    var colorHex: String = "#6C63FF"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(title: String = "", content: String = "") {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = content.split(separator: "\n").first.map(String.init) ?? ""
        return firstLine.isEmpty ? "새로운 메모" : firstLine
    }
}

// MARK: - Records

@Model
final class StudySession {
    var id: UUID = UUID()
    var title: String = ""
    var categoryName: String = ""
    var start: Date = Date()
    var seconds: Int = 0
    var planKey: String?

    init(title: String, categoryName: String, start: Date, seconds: Int, planKey: String?) {
        self.id = UUID()
        self.title = title
        self.categoryName = categoryName
        self.start = start
        self.seconds = seconds
        self.planKey = planKey
    }
}

// MARK: - Seed

enum SeedData {
    static func seedIfNeeded(_ context: ModelContext) {
        let key = "didSeedCategories"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<PlanCategory>())) ?? 0
        if existing == 0 {
            // 공부 과목(국어·영어·수학) + 일반 카테고리. 둘 다 사용자가 추가할 수 있음
            let defaults: [(String, String, String, Bool)] = [
                ("국어", "book.fill", "#EF4444", true),
                ("영어", "character.book.closed.fill", "#3B82F6", true),
                ("수학", "function", "#10B981", true),
                ("개인", "person.fill", "#EC4899", false),
                ("약속", "person.2.fill", "#F59E0B", false),
                ("운동", "figure.run", "#F97316", false)
            ]
            for (i, d) in defaults.enumerated() {
                context.insert(PlanCategory(name: d.0, symbol: d.1, colorHex: d.2, isStudy: d.3, sortIndex: i))
            }
            try? context.save()
        }
        UserDefaults.standard.set(true, forKey: key)
    }
}

// MARK: - AI 오답노트 도우미 (JSON 필드 읽기·쓰기)

extension MathNote {
    var kind: ProblemKind? {
        get { ProblemKind(rawValue: kindRaw) }
        set { kindRaw = newValue?.rawValue ?? "" }
    }
    /// 사용자가 인식 결과를 확인했는지 (예전 노트는 확인된 것으로 봄)
    var isRecognitionConfirmed: Bool {
        get { recognitionRaw != "pending" }
        set { recognitionRaw = newValue ? "confirmed" : "pending" }
    }
    var scan: ProblemScan? {
        get { scanData.flatMap { try? JSONDecoder().decode(ProblemScan.self, from: $0) } }
        set { scanData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }
    var grade: GradeResult? {
        get { gradeData.flatMap { try? JSONDecoder().decode(GradeResult.self, from: $0) } }
        set { gradeData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }
    var analysis: MistakeAnalysis? {
        get { analysisData.flatMap { try? JSONDecoder().decode(MistakeAnalysis.self, from: $0) } }
        set { analysisData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }
    var ladder: PracticeLadder? {
        get { ladderData.flatMap { try? JSONDecoder().decode(PracticeLadder.self, from: $0) } }
        set { ladderData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }
}

// MARK: - 취약 개념 (오답 기록으로 관리)

@Model
final class WeakConcept {
    /// 과목|단원|개념
    var key: String = ""
    var subject: String = ""
    var gradeLabel: String = ""
    var unit: String = ""
    var concept: String = ""
    var problemType: String = ""
    var wrongCount: Int = 0
    var attemptCount: Int = 0
    var mastery: Double = 0.3
    var lastStudiedAt: Date = Date()
    var lastWrongAt: Date?
    var lastAnswer: String = ""
    var lastCorrectAnswer: String = ""
    /// 오답 원인별 횟수 ([원인: 횟수] JSON)
    var causesData: Data?
    /// 풀이 기록 (DoitMastery.Record 목록 JSON, 최근 40개)
    var recordsData: Data?
    var createdAt: Date = Date()

    init(key: String, subject: String, unit: String, concept: String, problemType: String) {
        self.key = key
        self.subject = subject
        self.unit = unit
        self.concept = concept
        self.problemType = problemType
        self.createdAt = Date()
        self.lastStudiedAt = Date()
    }

    var records: [DoitMastery.Record] {
        get { recordsData.flatMap { try? JSONDecoder().decode([DoitMastery.Record].self, from: $0) } ?? [] }
        set { recordsData = try? JSONEncoder().encode(Array(newValue.suffix(40))) }
    }

    var causes: [String: Int] {
        get { causesData.flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:] }
        set { causesData = try? JSONEncoder().encode(newValue) }
    }

    var state: DoitMastery.State { DoitMastery.state(mastery: mastery, records: records, wrongCount: wrongCount) }
    var isWeak: Bool { DoitMastery.isWeak(mastery: mastery, wrongCount: wrongCount) }
    var mainCause: String? { causes.max { $0.value < $1.value }?.key }

    /// 풀이 한 번 기록 (정답·오답, 단계, 어디서 풀었는지)
    func record(correct: Bool, level: Int, source: String, answer: String = "", correctAnswer: String = "", cause: String? = nil) {
        attemptCount += 1
        if !correct {
            wrongCount += 1
            lastWrongAt = Date()
            if let cause { var c = causes; c[cause, default: 0] += 1; causes = c }
        }
        mastery = DoitMastery.updated(mastery, correct: correct, level: level)
        var list = records
        list.append(DoitMastery.Record(date: Date(), correct: correct, level: level, source: source))
        records = list
        lastStudiedAt = Date()
        if !answer.isEmpty { lastAnswer = answer }
        if !correctAnswer.isEmpty { lastCorrectAnswer = correctAnswer }
    }
}
