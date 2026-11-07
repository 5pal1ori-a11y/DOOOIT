import Foundation

/// 목표 달성 배지: 저장된 공부 기록으로 계산 (배지 자체는 저장하지 않고, 처음 받은 날짜만 기억)
/// - 화면·저장소와 떨어진 순수 계산이라 테스트에서 바로 확인할 수 있어요
enum BadgeBook {
    /// 배지를 계산하는 데 쓰는 숫자 묶음
    struct Stats: Equatable {
        /// 가장 길게 이어서 공부한 날 수 (끊겨도 한 번 받은 배지는 그대로)
        var bestStreak = 0
        var totalSeconds = 0
        var learnedWords = 0
        /// 틀렸던 개념을 다시 맞힌 횟수
        var fixedWrong = 0
        /// AI 풀이·질문을 쓴 횟수
        var aiSolves = 0
        var mockExams = 0
        var mockPerfects = 0
        /// 25분 이상 집중한 횟수
        var focus25 = 0
        /// 하루 최고 공부 시간 (초)
        var bestDaySeconds = 0
        var notes = 0
        /// 초대에 성공한 친구 수 (InviteRewards가 세어 둔 값)
        var invites = 0
    }

    enum Metric: String {
        case streak, hours, words, fixed, ai, mock, perfect, focus, bestDay, notes, invites

        func value(_ s: Stats) -> Int {
            switch self {
            case .streak: return s.bestStreak
            case .hours: return s.totalSeconds / 3600
            case .words: return s.learnedWords
            case .fixed: return s.fixedWrong
            case .ai: return s.aiSolves
            case .mock: return s.mockExams
            case .perfect: return s.mockPerfects
            case .focus: return s.focus25
            case .bestDay: return s.bestDaySeconds / 3600
            case .notes: return s.notes
            case .invites: return s.invites
            }
        }

        /// "3 / 7일"처럼 붙이는 단위
        var unit: String {
            switch self {
            case .streak: return "일"
            case .hours, .bestDay: return "시간"
            case .words, .fixed, .notes: return "개"
            case .ai, .mock, .perfect, .focus: return "번"
            case .invites: return "명"
            }
        }
    }

    struct Badge: Identifiable, Equatable {
        let id: String
        let title: String
        /// 짧은 설명 (어떻게 받는지)
        let detail: String
        let symbol: String
        /// 파스텔 색 (#RRGGBB)
        let colorHex: String
        let metric: Metric
        let target: Int
        /// 기간·조건이 한정된 배지 (친구 초대)
        var limited = false
        /// 받으면 선셋 테마도 열리는 배지
        var unlocksTheme = false

        func value(_ stats: Stats) -> Int { metric.value(stats) }
        func progress(_ stats: Stats) -> Double { min(1, Double(value(stats)) / Double(max(target, 1))) }
        func isUnlocked(_ stats: Stats) -> Bool { value(stats) >= target }
        func progressText(_ stats: Stats) -> String { "\(min(value(stats), target)) / \(target)\(metric.unit)" }
    }

    static let flame = "#FF8A5C", clock = "#7C83F7", word = "#4FA3F7", fix = "#2FBF8F", ai = "#A78BFA", exam = "#F2709C", focus = "#F2B233", invite = "#14B8A6"

    static let all: [Badge] = [
        Badge(id: "streak3", title: "3일 연속", detail: "3일 이어서 공부", symbol: "flame", colorHex: flame, metric: .streak, target: 3),
        Badge(id: "streak7", title: "7일 연속", detail: "일주일 이어서 공부", symbol: "flame", colorHex: flame, metric: .streak, target: 7),
        Badge(id: "streak30", title: "30일 연속", detail: "한 달 이어서 공부", symbol: "flame", colorHex: flame, metric: .streak, target: 30),
        Badge(id: "streak100", title: "100일 연속", detail: "100일 이어서 공부", symbol: "crown", colorHex: flame, metric: .streak, target: 100),
        Badge(id: "hours10", title: "10시간", detail: "총 10시간 공부", symbol: "clock", colorHex: clock, metric: .hours, target: 10),
        Badge(id: "hours50", title: "50시간", detail: "총 50시간 공부", symbol: "hourglass", colorHex: clock, metric: .hours, target: 50),
        Badge(id: "hours100", title: "100시간", detail: "총 100시간 공부", symbol: "medal", colorHex: clock, metric: .hours, target: 100),
        Badge(id: "day3h", title: "하루 3시간", detail: "하루에 3시간 공부", symbol: "sun.max", colorHex: focus, metric: .bestDay, target: 3),
        Badge(id: "focus25x10", title: "집중 25분", detail: "25분 집중 10번", symbol: "timer", colorHex: focus, metric: .focus, target: 10),
        Badge(id: "words100", title: "단어 100", detail: "단어 100개 외움", symbol: "character.book.closed", colorHex: word, metric: .words, target: 100),
        Badge(id: "words500", title: "단어 500", detail: "단어 500개 외움", symbol: "books.vertical", colorHex: word, metric: .words, target: 500),
        Badge(id: "words1000", title: "단어 1000", detail: "단어 1000개 외움", symbol: "graduationcap", colorHex: word, metric: .words, target: 1000),
        Badge(id: "notes10", title: "오답노트 10", detail: "오답노트 10개", symbol: "pencil.and.list.clipboard", colorHex: fix, metric: .notes, target: 10),
        Badge(id: "fixed10", title: "다시 맞힘 10", detail: "틀린 문제 10번 다시 맞힘", symbol: "arrow.uturn.backward", colorHex: fix, metric: .fixed, target: 10),
        Badge(id: "fixed50", title: "다시 맞힘 50", detail: "틀린 문제 50번 다시 맞힘", symbol: "checkmark.seal", colorHex: fix, metric: .fixed, target: 50),
        Badge(id: "firstAI", title: "첫 AI 풀이", detail: "AI 풀이 처음 써 봄", symbol: "lightbulb", colorHex: ai, metric: .ai, target: 1),
        Badge(id: "mockFirst", title: "첫 모의고사", detail: "AI 모의고사 처음 봄", symbol: "doc.text", colorHex: exam, metric: .mock, target: 1),
        Badge(id: "mockPerfect", title: "모의고사 만점", detail: "AI 모의고사 만점", symbol: "star", colorHex: exam, metric: .perfect, target: 1),
        // 친구 초대 한정 배지 (숫자는 InviteRewards가 세고, 아이디는 InviteRewards.Tier.badgeID와 같음)
        Badge(id: "invite1", title: "첫 초대", detail: "초대한 친구 1명이 1시간 공부", symbol: "person.badge.plus", colorHex: invite, metric: .invites, target: 1, limited: true),
        Badge(id: "invite3", title: "초대 3명", detail: "초대한 친구 3명이 1시간 공부", symbol: "person.2", colorHex: invite, metric: .invites, target: 3, limited: true, unlocksTheme: true),
        Badge(id: "invite10", title: "초대 10명", detail: "초대한 친구 10명이 1시간 공부", symbol: "person.3", colorHex: invite, metric: .invites, target: 10, limited: true)
    ]

    static func badge(_ id: String) -> Badge? { all.first { $0.id == id } }

    // MARK: 받은 배지

    /// 새로 받은 배지: 지금 조건을 넘었고 아직 날짜가 없는 것 (처음 받은 날짜를 더한 목록도 돌려줌)
    static func refresh(stats: Stats, unlocked: [String: Date], now: Date = Date()) -> (unlocked: [String: Date], new: [Badge]) {
        var result = unlocked
        var fresh: [Badge] = []
        for badge in all where result[badge.id] == nil && badge.isUnlocked(stats) {
            result[badge.id] = now
            fresh.append(badge)
        }
        return (result, fresh)
    }

    /// 아직 못 받은 배지 중 가장 가까운 것 (진행률이 높은 순)
    static func next(stats: Stats, unlocked: [String: Date]) -> Badge? {
        all.filter { unlocked[$0.id] == nil && !$0.isUnlocked(stats) }
            .max { $0.progress(stats) < $1.progress(stats) }
    }

    /// 가장 최근에 받은 배지
    static func latest(unlocked: [String: Date]) -> Badge? {
        unlocked.max { $0.value < $1.value }.flatMap { badge($0.key) }
    }

    // MARK: 숫자 계산 도우미

    /// 가장 긴 연속 공부 일수 (공부한 날짜 목록으로)
    static func bestStreak(days: [Date], calendar: Calendar = .current) -> Int {
        let sorted = Set(days.map { calendar.startOfDay(for: $0) }).sorted()
        var best = 0, run = 0
        var previous: Date?
        for day in sorted {
            if let previous, let next = calendar.date(byAdding: .day, value: 1, to: previous), calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// 틀린 뒤 다시 맞힌 횟수: 풀이 기록(정답 여부, 시간 순)에서 오답 다음에 나온 정답마다 1
    static func fixedCount(_ results: [Bool]) -> Int {
        var count = 0
        var hadWrong = false
        for correct in results {
            if !correct { hadWrong = true } else if hadWrong { count += 1; hadWrong = false }
        }
        return count
    }

    /// 모의고사 기록 묶음(같은 시험의 맞은 수·문제 수) → (본 횟수, 만점 횟수)
    static func mockCounts(_ exams: [(correct: Int, total: Int)]) -> (taken: Int, perfect: Int) {
        let taken = exams.filter { $0.total > 0 }
        return (taken.count, taken.filter { $0.correct == $0.total && $0.total >= 10 }.count)
    }
}
