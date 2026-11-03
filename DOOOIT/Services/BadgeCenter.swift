import Foundation
import Observation
import SwiftData

/// 배지 받기: 저장된 기록으로 계산하고, 처음 받은 날짜만 설정에 기억 (계정마다 따로)
/// 앱을 열 때 · 공부를 마칠 때 · 채점한 뒤에 확인해서 새 배지가 있으면 살짝 축하해 줘요.
@MainActor
@Observable
final class BadgeCenter {
    static let shared = BadgeCenter()
    /// [배지 아이디: 처음 받은 시각] (AccountStore.personalKeys에 들어 있음)
    static let unlockedKey = "badges.unlocked"

    private(set) var unlocked: [String: Date] = [:]
    private(set) var stats = BadgeBook.Stats()
    /// 지금 보여 줄 축하 (배지 + 함께 받은 개수)
    private(set) var toast: Toast?

    struct Toast: Identifiable, Equatable {
        let badge: BadgeBook.Badge
        let more: Int
        var id: String { badge.id }
    }

    @ObservationIgnored private var queue: [BadgeBook.Badge] = []

    private init() {
        unlocked = Self.load()
    }

    var latest: BadgeBook.Badge? { BadgeBook.latest(unlocked: unlocked) }
    var next: BadgeBook.Badge? { BadgeBook.next(stats: stats, unlocked: unlocked) }

    func isUnlocked(_ badge: BadgeBook.Badge) -> Bool { unlocked[badge.id] != nil }

    /// 기록을 다시 세어 보고 새로 받은 배지가 있으면 축하
    func check(context: ModelContext) {
        // 계정을 바꾸면 그 계정의 날짜를 다시 읽음
        unlocked = Self.load()
        stats = Self.stats(context: context)
        let result = BadgeBook.refresh(stats: stats, unlocked: unlocked)
        guard !result.new.isEmpty else { return }
        unlocked = result.unlocked
        save()
        var celebrate = true
        #if DEBUG
        if UIShot.isActive && !UIShot.matches(.badgeNew) { celebrate = false }
        #endif
        guard celebrate else { return }
        queue += result.new
        if toast == nil { showNext() }
    }

    /// 축하를 닫음 (다음 것이 있으면 이어서)
    func dismissToast() {
        toast = nil
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            showNext()
        }
    }

    private func showNext() {
        guard toast == nil, let first = queue.first else { return }
        // 한꺼번에 많이 받으면 하나로 모아서 (처음 업데이트했을 때 등)
        let more = queue.count - 1
        queue.removeAll()
        Haptics.success()
        toast = Toast(badge: first, more: more)
        let id = first.id
        #if DEBUG
        // 화면 사진: 찍을 때까지 남겨 둠
        if UIShot.isActive { return }
        #endif
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            if toast?.id == id { dismissToast() }
        }
    }

    // MARK: 저장

    private static func load() -> [String: Date] {
        let raw = UserDefaults.standard.dictionary(forKey: unlockedKey) as? [String: Double] ?? [:]
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }

    private func save() {
        #if DEBUG
        // 화면 사진: 시뮬레이터 설정에 남기지 않음
        if UIShot.isActive { return }
        #endif
        UserDefaults.standard.set(unlocked.mapValues(\.timeIntervalSince1970), forKey: Self.unlockedKey)
    }

    // MARK: 기록 세기

    static func stats(context: ModelContext) -> BadgeBook.Stats {
        var s = BadgeBook.Stats()
        let sessions = (try? context.fetch(FetchDescriptor<StudySession>())) ?? []
        var byDay: [Date: Int] = [:]
        for session in sessions {
            s.totalSeconds += session.seconds
            if session.seconds >= 25 * 60 { s.focus25 += 1 }
            byDay[session.start.startOfDay, default: 0] += session.seconds
        }
        s.bestDaySeconds = byDay.values.max() ?? 0
        s.bestStreak = BadgeBook.bestStreak(days: byDay.filter { $0.value >= 60 }.map(\.key))

        let words = (try? context.fetch(FetchDescriptor<Word>())) ?? []
        s.learnedWords = words.filter(\.isLearned).count

        let notes = (try? context.fetch(FetchDescriptor<MathNote>())) ?? []
        s.notes = notes.count
        let concepts = (try? context.fetch(FetchDescriptor<WeakConcept>())) ?? []
        s.fixedWrong = concepts.reduce(0) { $0 + BadgeBook.fixedCount($1.records.map(\.correct)) }

        let questions = (try? context.fetchCount(FetchDescriptor<AIQuestion>())) ?? 0
        s.aiSolves = questions + notes.filter { $0.solutionData != nil }.count

        // 모의고사: 같은 시각에 저장한 단원별 기록이 한 번의 시험
        let records = ((try? context.fetch(FetchDescriptor<QuizRecord>())) ?? []).filter { $0.step == DoitMockExam.step }
        let exams = Dictionary(grouping: records, by: \.date).values.map { group in
            (correct: group.reduce(0) { $0 + $1.correct }, total: group.reduce(0) { $0 + $1.total })
        }
        let mock = BadgeBook.mockCounts(exams)
        s.mockExams = mock.taken
        s.mockPerfects = mock.perfect
        return s
    }
}
