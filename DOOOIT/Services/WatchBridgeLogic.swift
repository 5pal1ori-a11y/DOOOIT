import Foundation

/// 애플 워치 연결에서 SwiftData·WatchConnectivity 없이 계산하는 부분 (리눅스 테스트에서도 검사)
enum WatchBridgeLogic {
    // MARK: 타이머 명령

    enum TimerAction: Equatable {
        case start(targetMinutes: Int?)
        case pause, resume, stop
        case none
    }

    /// 워치 명령을 지금 타이머 상태에 맞게 바꿈 (아이폰에서 이미 돌고 있으면 새로 시작하지 않음)
    static func timerAction(for action: WatchCommand.Action, phase: WatchTimerPhase) -> TimerAction {
        switch (action, phase) {
        case (.startTimer(let minutes), .idle): return .start(targetMinutes: minutes.map { min(max($0, 1), 12 * 60) })
        case (.pauseTimer, .running): return .pause
        case (.resumeTimer, .paused): return .resume
        case (.stopTimer, .running), (.stopTimer, .paused): return .stop
        default: return .none
        }
    }

    /// 명령이 실제로 눌린 시각 (늦게 도착해도 기록이 맞게). 미래나 너무 옛날은 잘라 냄
    static func effectiveTime(sentAt: Date, now: Date) -> Date {
        min(now, max(sentAt, now.addingTimeInterval(-6 * 3600)))
    }

    // MARK: 오늘 공부 시간

    static func todaySeconds(_ sessions: [(start: Date, seconds: Int)], now: Date, calendar: Calendar = .current) -> Int {
        sessions.filter { calendar.isDate($0.start, inSameDayAs: now) }.reduce(0) { $0 + $1.seconds }
    }

    // MARK: 단어 카드

    struct WordInfo: Equatable {
        var id: String
        var term: String
        var meaning: String
        var reviewStage: Int
        var nextReviewAt: Date?
    }

    /// 오늘 복습할 단어 (오래 기다린 것부터, 워치에는 조금만)
    static func reviewDeck(_ words: [WordInfo], now: Date, limit: Int = 15) -> [WatchWordItem] {
        words
            .filter { WordReview.isDue(stage: $0.reviewStage, next: $0.nextReviewAt, now: now) }
            .filter { !$0.term.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { ($0.nextReviewAt ?? .distantPast) < ($1.nextReviewAt ?? .distantPast) }
            .prefix(limit)
            .map { WatchWordItem(id: $0.id, term: $0.term, meaning: $0.meaning) }
    }

    struct WordState: Equatable {
        var reviewStage: Int
        var nextReviewAt: Date?
        var correctCount: Int
        var wrongCount: Int
    }

    /// 알아요/몰라요 결과를 복습 일정에 반영 (앱의 복습과 같은 규칙). 이미 처리했거나 복습 차례가 아니면 nil
    static func graded(_ state: WordState, known: Bool, now: Date, calendar: Calendar = .current) -> WordState? {
        guard WordReview.isDue(stage: state.reviewStage, next: state.nextReviewAt, now: now) else { return nil }
        var next = state
        if known { next.correctCount += 1 } else { next.wrongCount += 1 }
        let schedule = WordReview.afterReview(stage: state.reviewStage, correct: known, now: now, calendar: calendar)
        next.reviewStage = schedule.stage
        next.nextReviewAt = schedule.next
        return next
    }

    // MARK: 할 일

    /// 체크 상태를 바꿔야 하는지 (같은 명령이 두 번 와도 한 번만 바뀜)
    static func needsToggle(isCompleted: Bool, wantDone: Bool) -> Bool { isCompleted != wantDone }

    // MARK: 같은 명령 두 번 막기

    struct Recent: Equatable {
        private(set) var ids: [String]
        let limit: Int

        init(_ ids: [String] = [], limit: Int = 60) {
            self.ids = Array(ids.suffix(limit))
            self.limit = limit
        }

        func contains(_ id: String) -> Bool { ids.contains(id) }

        /// 처음 보는 id면 넣고 true
        mutating func insert(_ id: String) -> Bool {
            guard !ids.contains(id) else { return false }
            ids.append(id)
            if ids.count > limit { ids.removeFirst(ids.count - limit) }
            return true
        }
    }
}
