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
        case (.startSession(let start), .idle): return .start(targetMinutes: start.targetMinutes.map { min(max($0, 1), 12 * 60) })
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

    struct QuickPlan: Equatable {
        var title: String
        var dateText: String
        var timeText: String?
        var minutes: Int?
        var isStudy: Bool
    }

    /// 워치에서 말로 넣은 할 일 → 모티 AI와 같은 방법으로 날짜 · 시간 · 걸리는 시간 · 이름을 나눔
    /// ("내일 오후 4시 수학 1시간" → 내일, 오후 4시, 60분, 수학). 날짜를 말하지 않으면 고른 날
    @MainActor
    static func quickPlan(_ text: String, dayKey: String) -> QuickPlan? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var rest = trimmed
        let date = DoitEngine.findDate(in: rest)
        if let date { rest = rest.replacingOccurrences(of: date, with: " ") }
        let time = DoitEngine.findTime(in: rest)
        if let time { rest = rest.replacingOccurrences(of: time, with: " ") }
        let duration = DoitEngine.findDuration(in: rest)
        let title = DoitEngine.planTitle(from: trimmed) ?? trimmed
        return QuickPlan(title: String(title.prefix(60)), dateText: date ?? dayKey, timeText: time,
                         minutes: duration?.minutes, isStudy: DoitEngine.looksLikeStudy(trimmed))
    }

    // MARK: 이번 주 · 연속 공부일

    /// 지난 7일 공부 시간 (초, 마지막 칸이 오늘)
    static func weekSeconds(_ sessions: [(start: Date, seconds: Int)], now: Date, calendar: Calendar = .current) -> [Int] {
        let today = calendar.startOfDay(for: now)
        var days = Array(repeating: 0, count: 7)
        for session in sessions {
            let day = calendar.startOfDay(for: session.start)
            guard let back = calendar.dateComponents([.day], from: day, to: today).day, (0..<7).contains(back) else { continue }
            days[6 - back] += session.seconds
        }
        return days
    }

    /// 연속 공부일: 1분 넘게 공부한 날이 이어진 수 (오늘 아직 안 했으면 어제부터 셈, 위젯과 같은 규칙)
    static func streak(_ sessions: [(start: Date, seconds: Int)], now: Date, calendar: Calendar = .current) -> Int {
        var byDay: [Date: Int] = [:]
        for session in sessions { byDay[calendar.startOfDay(for: session.start), default: 0] += session.seconds }
        let studied = Set(byDay.filter { $0.value >= 60 }.map(\.key))
        var day = calendar.startOfDay(for: now)
        if !studied.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var count = 0
        while studied.contains(day), count < 3_650 {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    // MARK: D-Day

    /// 오늘이나 앞으로 올 D-Day만, 가까운 것부터 (같은 날 같은 이름은 하나만)
    static func ddays(_ items: [(id: String, title: String, date: Date)], now: Date, limit: Int = 5,
                      calendar: Calendar = .current) -> [WatchDDay] {
        let today = calendar.startOfDay(for: now)
        var seen = Set<String>()
        return items
            .filter { calendar.startOfDay(for: $0.date) >= today && !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.date < $1.date }
            .compactMap { item -> WatchDDay? in
                let key = WatchLink.dayKey(item.date)
                guard seen.insert("\(item.title)|\(key)").inserted else { return nil }
                return WatchDDay(id: item.id, title: String(item.title.prefix(30)), dayKey: key)
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: 단어 퀴즈

    /// 늘 같은 순서를 만드는 해시 (FNV-1a, 실행할 때마다 바뀌는 hashValue 대신)
    static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    /// 4지선다 보기: 정답 + 다른 단어 뜻 3개 (같은 단어 · 같은 날이면 늘 같은 보기라 워치로 다시 보낼 일이 적음)
    static func quizChoices(answer: String, pool: [String], seed: String, count: Int = 4) -> [String]? {
        let key = answer.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        var seen = Set([key])
        let others = pool
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .sorted { stableHash(seed + $0) < stableHash(seed + $1) }
            .prefix(count - 1)
        guard others.count == count - 1 else { return nil }
        var choices = Array(others)
        choices.insert(key, at: Int(stableHash(seed) % UInt64(count)))
        return choices
    }

    /// 퀴즈 연습 단어 (복습 차례가 아닌 것, 날마다 다르게)
    static func practiceDeck(_ words: [WordInfo], excluding: Set<String>, now: Date, limit: Int = 6) -> [WatchWordItem] {
        let day = WatchLink.dayKey(now)
        return words
            .filter { !excluding.contains($0.id) }
            .filter { !$0.term.trimmingCharacters(in: .whitespaces).isEmpty && !$0.meaning.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { stableHash(day + $0.id) < stableHash(day + $1.id) }
            .prefix(limit)
            .map { WatchWordItem(id: $0.id, term: $0.term, meaning: $0.meaning) }
    }

    /// 단어마다 보기 붙이기 (뜻 보기는 내 단어장 전체에서)
    static func withChoices(_ items: [WatchWordItem], meanings: [String], day: String) -> [WatchWordItem] {
        items.map { item in
            var item = item
            item.choices = quizChoices(answer: item.meaning, pool: meanings, seed: day + item.id)
            return item
        }
    }

    /// 오늘 외우거나 복습한 단어인지: 복습 규칙상 다음 복습 날이 "오늘 + 그 단계 간격"이면 오늘 본 것
    static func reviewedToday(stage: Int, next: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard (1...WordReview.intervals.count).contains(stage), let next else { return false }
        let today = calendar.startOfDay(for: now)
        guard let expected = calendar.date(byAdding: .day, value: WordReview.intervals[stage - 1], to: today) else { return false }
        return calendar.isDate(next, inSameDayAs: expected)
    }

    // MARK: 모티 답

    /// 워치 화면용으로 짧게 (굵게 표시 · 코드 기호 빼고, 길면 자름)
    static func shortAnswer(_ raw: String, limit: Int = 400) -> String {
        var text = raw.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
        while text.contains("\n\n\n") { text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > limit else { return text.isEmpty ? "잘 모르겠어요" : text }
        return String(text.prefix(limit - 1)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

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
