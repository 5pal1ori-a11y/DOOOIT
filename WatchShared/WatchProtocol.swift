import Foundation

// 아이폰 ↔ 애플 워치가 주고받는 자료 (WatchConnectivity)
// 아이폰 앱 · 워치 앱 · 워치 위젯(컴플리케이션)이 같이 쓰는 파일이라 Foundation만 씀
// - 아이폰 → 워치: WatchSnapshot (오늘 공부 시간 · 목표 · 타이머 · 할 일 · 복습 단어 · 이번 주 · 연속 · D-Day · 모티 답)
// - 워치 → 아이폰: WatchCommand (타이머 시작/멈춤/끝, 할 일 체크/추가, 단어 알아요/몰라요, 모티에게 묻기)
// 기록은 모두 아이폰 앱이 저장하고, 워치는 리모컨 + 화면

enum WatchLink {
    static let version = 1
    static let snapshotKey = "snapshot"
    static let commandKey = "command"
    static let appGroup = "group.com.donghyeon.moti"
    /// 기본 강조색 (라벤더)
    static let defaultAccentHex = "#7B68EE"

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// 아이폰 앱의 날짜 키와 같은 모양 (yyyy-MM-dd, 양력)
    static func dayKey(_ date: Date) -> String { dayKeyFormatter.string(from: date) }
    static func date(fromDayKey key: String) -> Date? { dayKeyFormatter.date(from: key) }

    static func encode<T: Encodable>(_ value: T) -> Data? { try? JSONEncoder().encode(value) }
    static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - 타이머

enum WatchTimerPhase: String, Codable {
    case idle, running, paused
}

/// 타이머 상태 (두 기기의 시계로 계산할 수 있게 "언제부터 흘렀는지"로 보냄)
struct WatchTimerState: Codable, Equatable {
    var phase: WatchTimerPhase = .idle
    var title: String = ""
    var targetSeconds: Int?
    /// 흐르는 중: 지금 - runningSince = 지난 시간
    var runningSince: Date?
    /// 멈춤: 멈춘 때까지 지난 시간 (초)
    var pausedElapsed: Double = 0

    var isActive: Bool { phase != .idle }

    static func make(phase: WatchTimerPhase, title: String, targetSeconds: Int?, elapsed: TimeInterval, now: Date) -> WatchTimerState {
        switch phase {
        case .idle:
            return WatchTimerState()
        case .running:
            return WatchTimerState(phase: .running, title: title, targetSeconds: targetSeconds,
                                   runningSince: now.addingTimeInterval(-max(0, elapsed)), pausedElapsed: 0)
        case .paused:
            return WatchTimerState(phase: .paused, title: title, targetSeconds: targetSeconds,
                                   runningSince: nil, pausedElapsed: max(0, elapsed))
        }
    }

    func elapsed(at date: Date) -> TimeInterval {
        switch phase {
        case .idle: return 0
        case .paused: return pausedElapsed
        case .running: return max(0, date.timeIntervalSince(runningSince ?? date))
        }
    }

    func remaining(at date: Date) -> TimeInterval? {
        targetSeconds.map { max(0, Double($0) - elapsed(at: date)) }
    }

    /// 목표 시간 대비 (0~1), 목표가 없으면 nil
    func progress(at date: Date) -> Double? {
        guard let targetSeconds, targetSeconds > 0 else { return nil }
        return min(1, elapsed(at: date) / Double(targetSeconds))
    }

    /// 흐르는 중이고 목표가 있으면 목표에 닿는 시각
    var goalDate: Date? {
        guard phase == .running, let targetSeconds, let runningSince else { return nil }
        return runningSince.addingTimeInterval(Double(targetSeconds))
    }

    /// 디지털 크라운으로 고르는 목표 (nil = ∞, 5분 단위 ~ 4시간)
    static let targetChoices: [Int?] = [nil] + Array(stride(from: 5, through: 240, by: 5))

    static func targetLabel(_ minutes: Int?) -> String {
        guard let minutes else { return "∞" }
        if minutes < 60 { return "\(minutes)분" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
    }
}

// MARK: - 오늘 자료

struct WatchPlanItem: Codable, Equatable, Hashable, Identifiable {
    /// 그날 일정 id (플랜 id_날짜)
    var id: String
    var planID: String
    var dayKey: String
    var title: String
    var time: String
    var colorHex: String
    var isDone: Bool
    var isStudy: Bool
    /// 시작 시각 (종일 일정은 nil) — 다음 일정 · 컴플리케이션용
    var start: Date? = nil

    /// 워치에서 막 추가해서 아직 아이폰이 저장하지 않은 일정
    var isSending: Bool { id.hasPrefix("new-") }
}

struct WatchWordItem: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var term: String
    var meaning: String
    /// 4지선다 보기 (정답 포함, 단어가 적으면 nil)
    var choices: [String]? = nil
}

/// D-Day (설정의 D-Day · 시험 계획)
struct WatchDDay: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var title: String
    var dayKey: String

    /// 오늘부터 남은 날 (지났으면 음수)
    func days(from date: Date, calendar: Calendar = .current) -> Int {
        guard let day = WatchLink.date(fromDayKey: dayKey) else { return 0 }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: day)).day ?? 0
    }

    /// D-3 · D-Day · D+2
    func label(from date: Date) -> String {
        let n = days(from: date)
        if n == 0 { return "D-Day" }
        return n > 0 ? "D-\(n)" : "D+\(-n)"
    }
}

/// 모티에게 물어본 것의 답 (아이폰의 규칙형 모티 엔진, 인터넷 없이)
struct WatchAnswer: Codable, Equatable {
    /// 물어본 명령 id
    var id: String
    var question: String
    var text: String
}

/// 아이폰이 워치에 보내는 지금 상태 (applicationContext로 마지막 것만 유지)
struct WatchSnapshot: Codable, Equatable {
    var version = WatchLink.version
    var updatedAt = Date(timeIntervalSince1970: 0)
    var dayKey = ""
    /// 오늘 저장된 공부 시간 (진행 중인 타이머는 빼고, 초)
    var savedSeconds = 0
    var goalMinutes = 180
    var accentHex = WatchLink.defaultAccentHex
    var timer = WatchTimerState()
    var plans: [WatchPlanItem] = []
    var words: [WatchWordItem] = []
    /// 아이폰이 최근에 처리한 명령 id (워치가 기다리던 표시를 지움)
    var applied: [String] = []
    /// 지난 7일 공부 시간 (초, 마지막 칸이 오늘 · 진행 중인 타이머는 빼고)
    var week: [Int] = []
    /// 연속 공부일
    var streak = 0
    /// 다가오는 D-Day (가까운 것부터)
    var ddays: [WatchDDay] = []
    /// 내일 할 일
    var tomorrow: [WatchPlanItem] = []
    /// 퀴즈 연습용 단어 (복습 차례가 아닌 것)
    var practice: [WatchWordItem] = []
    /// 오늘 외우거나 복습한 단어 수
    var wordsToday = 0
    /// 다시 풀 오답 노트 수
    var mistakes = 0
    /// 모티의 마지막 답
    var answer: WatchAnswer?

    enum CodingKeys: String, CodingKey {
        case version, updatedAt, dayKey, savedSeconds, goalMinutes, accentHex, timer, plans, words, applied
        case week, streak, ddays, tomorrow, practice, wordsToday, mistakes, answer
    }

    var isEmpty: Bool { dayKey.isEmpty }

    /// 남은 오늘 할 일 수
    var remainingCount: Int { plans.filter { !$0.isDone }.count }

    /// 다음 일정 (아직 시작 전이고 완료하지 않은 것)
    func nextPlan(at date: Date) -> WatchPlanItem? {
        plans.filter { !$0.isDone && ($0.start.map { $0 > date } ?? false) }
            .min { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }

    /// 이번 주 막대 (오늘 칸은 진행 중인 타이머 포함)
    func weekSeconds(at date: Date) -> [Int] {
        var days = week.isEmpty ? [0] : week
        days[days.count - 1] = studySeconds(at: date)
        return days
    }

    /// 지금 타이머가 계속 흐르면 오늘 목표에 닿는 시각
    func dailyGoalDate(at date: Date) -> Date? {
        guard timer.phase == .running, goalMinutes > 0 else { return nil }
        let left = goalMinutes * 60 - studySeconds(at: date)
        return left > 0 ? date.addingTimeInterval(Double(left)) : nil
    }

    /// 연속 공부일 (오늘 공부를 시작하면 바로 +1)
    func streak(at date: Date) -> Int {
        let todayStudied = (week.last ?? 0) >= 60
        return !todayStudied && studySeconds(at: date) >= 60 ? streak + 1 : streak
    }

    /// 오늘 공부 시간 (진행 중인 타이머 포함, 초)
    func studySeconds(at date: Date) -> Int {
        let saved = dayKey == WatchLink.dayKey(date) ? savedSeconds : 0
        return saved + Int(timer.elapsed(at: date))
    }

    func goalProgress(at date: Date) -> Double {
        guard goalMinutes > 0 else { return 0 }
        return min(1, Double(studySeconds(at: date)) / Double(goalMinutes * 60))
    }

    /// 어제 받은 자료면 오늘 것만 남김 (진행 중인 타이머는 그대로)
    func forToday(_ date: Date, calendar: Calendar = .current) -> WatchSnapshot {
        guard !isEmpty, dayKey != WatchLink.dayKey(date) else { return self }
        var copy = self
        let gap = WatchLink.date(fromDayKey: dayKey).map {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: date)).day ?? 99
        } ?? 99
        let todayKey = WatchLink.dayKey(date)
        copy.savedSeconds = 0
        // 하루 지났으면 받아 둔 내일 할 일이 오늘 할 일
        copy.plans = gap == 1 ? tomorrow.filter { $0.dayKey == todayKey } : []
        copy.tomorrow = []
        copy.words = []
        copy.practice = gap == 1 ? practice : []
        copy.wordsToday = 0
        if !week.isEmpty, gap > 0 {
            copy.week = Array((week + Array(repeating: 0, count: min(gap, 7))).suffix(7))
        }
        // 어제 공부했으면 연속은 그대로, 하루 넘게 쉬었으면 0
        let lastStudied = (week.last ?? 0) >= 60
        if gap > 1 || (gap == 1 && !lastStudied) { copy.streak = 0 }
        copy.dayKey = todayKey
        return copy
    }

    var message: [String: Any] {
        guard let data = WatchLink.encode(self) else { return [:] }
        return [WatchLink.snapshotKey: data]
    }

    static func from(_ message: [String: Any]) -> WatchSnapshot? {
        WatchLink.decode(WatchSnapshot.self, message[WatchLink.snapshotKey] as? Data)
    }

    /// 아직 아이폰이 처리하지 않은 워치 명령을 미리 반영 (누르자마자 화면이 바뀌게)
    func applying(_ pending: [WatchCommand]) -> WatchSnapshot {
        var s = self
        for command in pending where !applied.contains(command.id) {
            let at = command.effectiveDate
            switch command.action {
            case .startTimer(let minutes):
                guard !s.timer.isActive else { continue }
                s.timer = WatchTimerState(phase: .running, title: "자유 공부", targetSeconds: minutes.map { $0 * 60 },
                                          runningSince: at, pausedElapsed: 0)
            case .startSession(let start):
                guard !s.timer.isActive else { continue }
                let planTitle = (s.plans + s.tomorrow).first { $0.planID == start.planID && start.planID != nil }?.title
                s.timer = WatchTimerState(phase: .running, title: planTitle ?? start.title ?? "자유 공부",
                                          targetSeconds: start.targetMinutes.map { $0 * 60 }, runningSince: at, pausedElapsed: 0)
            case .pauseTimer:
                guard s.timer.phase == .running else { continue }
                s.timer = WatchTimerState.make(phase: .paused, title: s.timer.title, targetSeconds: s.timer.targetSeconds,
                                               elapsed: s.timer.elapsed(at: at), now: at)
            case .resumeTimer:
                guard s.timer.phase == .paused else { continue }
                s.timer = WatchTimerState.make(phase: .running, title: s.timer.title, targetSeconds: s.timer.targetSeconds,
                                               elapsed: s.timer.pausedElapsed, now: at)
            case .stopTimer:
                guard s.timer.isActive else { continue }
                let seconds = Int(s.timer.elapsed(at: at))
                // 아이폰도 10초보다 짧은 기록은 저장하지 않음
                if seconds >= 10 { s.savedSeconds += seconds }
                s.timer = WatchTimerState()
            case .setPlanDone(_, _, let done):
                if let i = s.plans.firstIndex(where: { $0.id == command.targetID }) { s.plans[i].isDone = done }
                if let i = s.tomorrow.firstIndex(where: { $0.id == command.targetID }) { s.tomorrow[i].isDone = done }
            case .gradeWord(let wordID, _):
                if s.words.contains(where: { $0.id == wordID }) { s.wordsToday += 1 }
                s.words.removeAll { $0.id == wordID }
            case .addPlan(let text, let day):
                let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { continue }
                let item = WatchPlanItem(id: "new-\(command.id)", planID: "", dayKey: day, title: title, time: "보내는 중",
                                         colorHex: s.accentHex, isDone: false, isStudy: false)
                if day == s.dayKey { s.plans.append(item) } else { s.tomorrow.append(item) }
            case .ask, .refresh:
                continue
            }
        }
        return s
    }

    /// 아이폰이 처리했거나 너무 오래된 명령은 지움
    func stillPending(_ pending: [WatchCommand], now: Date) -> [WatchCommand] {
        pending.filter { command in
            !applied.contains(command.id)
                && updatedAt.timeIntervalSince(command.sentAt) < 600
                && now.timeIntervalSince(command.sentAt) < 6 * 3600
        }
    }
}

extension WatchSnapshot {
    /// 앱 버전이 달라 빠진 칸이 있어도 읽음 (없는 칸은 기본값)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WatchSnapshot()
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? d.version
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? d.updatedAt
        dayKey = try c.decodeIfPresent(String.self, forKey: .dayKey) ?? d.dayKey
        savedSeconds = try c.decodeIfPresent(Int.self, forKey: .savedSeconds) ?? d.savedSeconds
        goalMinutes = try c.decodeIfPresent(Int.self, forKey: .goalMinutes) ?? d.goalMinutes
        accentHex = try c.decodeIfPresent(String.self, forKey: .accentHex) ?? d.accentHex
        timer = try c.decodeIfPresent(WatchTimerState.self, forKey: .timer) ?? d.timer
        plans = try c.decodeIfPresent([WatchPlanItem].self, forKey: .plans) ?? d.plans
        words = try c.decodeIfPresent([WatchWordItem].self, forKey: .words) ?? d.words
        applied = try c.decodeIfPresent([String].self, forKey: .applied) ?? d.applied
        week = try c.decodeIfPresent([Int].self, forKey: .week) ?? d.week
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? d.streak
        ddays = try c.decodeIfPresent([WatchDDay].self, forKey: .ddays) ?? d.ddays
        tomorrow = try c.decodeIfPresent([WatchPlanItem].self, forKey: .tomorrow) ?? d.tomorrow
        practice = try c.decodeIfPresent([WatchWordItem].self, forKey: .practice) ?? d.practice
        wordsToday = try c.decodeIfPresent(Int.self, forKey: .wordsToday) ?? d.wordsToday
        mistakes = try c.decodeIfPresent(Int.self, forKey: .mistakes) ?? d.mistakes
        answer = try c.decodeIfPresent(WatchAnswer.self, forKey: .answer)
    }

    /// 보낼 크기 (applicationContext는 약 65KB까지라 훨씬 작게 유지)
    var byteSize: Int { WatchLink.encode(self)?.count ?? 0 }

    /// 컴플리케이션이 쓰는 부분 (바뀔 때만 다시 그리게)
    var complicationDigest: Data? {
        var s = self
        s.updatedAt = Date(timeIntervalSince1970: 0)
        s.words = []
        s.practice = []
        s.applied = []
        s.answer = nil
        return WatchLink.encode(s)
    }
}

// MARK: - 뽀모도로 (워치에서만 도는 집중 · 휴식 순서)

/// 집중은 아이폰 타이머로 기록하고, 휴식은 워치에서만 셈
struct WatchFocusCycle: Codable, Equatable {
    enum Stage: String, Codable {
        /// 집중 중 (아이폰 타이머가 목표와 함께 도는 중)
        case focus
        /// 쉬는 중
        case rest
        /// 휴식 끝, 다음 집중을 기다림
        case ready
    }

    enum Event: Equatable {
        /// 집중 끝 (이 시각으로 타이머를 끝내 기록)
        case focusDone(at: Date)
        case restDone
        /// 다른 타이머로 바뀌었거나 직접 끝냄
        case cancelled
    }

    var focusMinutes = 25
    var restMinutes = 5
    var longRestMinutes = 15
    /// 네 번 집중마다 길게 쉼
    var roundsPerSet = 4
    /// 지금 몇 번째 집중
    var round = 1
    var stage: Stage = .focus
    var restUntil: Date?
    /// 휴식 버튼으로 쉬기만
    var restOnly = false

    static func rest(minutes: Int, now: Date) -> WatchFocusCycle {
        var c = WatchFocusCycle()
        c.stage = .rest
        c.restMinutes = minutes
        c.restUntil = now.addingTimeInterval(Double(minutes) * 60)
        c.restOnly = true
        return c
    }

    /// 이번 집중 뒤에 쉬는 시간 (분)
    var restLength: Int {
        restOnly ? restMinutes : (round % max(1, roundsPerSet) == 0 ? longRestMinutes : restMinutes)
    }

    var isLongRest: Bool { !restOnly && round % max(1, roundsPerSet) == 0 }

    /// 이 집중의 타이머인지 (목표 시간이 같아야 함)
    func owns(_ timer: WatchTimerState) -> Bool {
        timer.isActive && timer.targetSeconds == focusMinutes * 60
    }

    /// 시간이 지나 다음 단계로 (일이 생기면 알려 줌)
    mutating func update(timer: WatchTimerState, now: Date) -> Event? {
        switch stage {
        case .focus:
            guard owns(timer) else { return .cancelled }
            guard let goal = timer.goalDate, goal <= now else { return nil }
            let until = goal.addingTimeInterval(Double(restLength) * 60)
            restUntil = until
            stage = until <= now ? .ready : .rest
            return .focusDone(at: goal)
        case .rest:
            guard let until = restUntil, until <= now else { return nil }
            stage = .ready
            return .restDone
        case .ready:
            return nil
        }
    }

    /// 쉬는 중에 바로 다음 집중으로
    mutating func skipRest() {
        guard stage == .rest else { return }
        stage = .ready
    }

    /// 다음 집중 시작
    mutating func nextFocus() {
        round += 1
        stage = .focus
        restUntil = nil
    }

    /// 다음에 진동할 시각
    func nextEventDate(timer: WatchTimerState) -> Date? {
        switch stage {
        case .focus: return timer.goalDate
        case .rest: return restUntil
        case .ready: return nil
        }
    }
}

// MARK: - 명령

/// 타이머 시작 요청
struct WatchStart: Codable, Equatable, Hashable {
    var targetMinutes: Int?
    /// 붙일 할 일 (그날 일정)
    var planID: String?
    var dayKey: String?
    /// 할 일 없이 시작할 때 이름 (뽀모도로 등)
    var title: String?
}

struct WatchCommand: Codable, Equatable, Identifiable {
    enum Action: Codable, Equatable {
        case startTimer(targetMinutes: Int?)
        case pauseTimer
        case resumeTimer
        case stopTimer
        /// 할 일 체크 (done = 바뀐 뒤 상태)
        case setPlanDone(planID: String, dayKey: String, done: Bool)
        /// 단어 카드 결과 (known = 알아요)
        case gradeWord(wordID: String, known: Bool)
        /// 최신 상태 다시 보내 줘
        case refresh
        /// 타이머 시작 (할 일에 붙이거나 이름을 붙여서)
        case startSession(WatchStart)
        /// 할 일 추가 (받아쓰기 · 손글씨, "내일 4시 수학"처럼 말해도 됨)
        case addPlan(text: String, dayKey: String)
        /// 모티에게 묻기
        case ask(text: String)
    }

    var id: String = UUID().uuidString
    var sentAt: Date = Date()
    var action: Action
    /// 실제로 일어난 시각 (뽀모도로 집중이 끝난 때처럼 보낸 때와 다를 수 있음)
    var at: Date?

    init(_ action: Action, id: String = UUID().uuidString, sentAt: Date = Date(), at: Date? = nil) {
        self.action = action
        self.id = id
        self.sentAt = sentAt
        self.at = at
    }

    /// 기록에 쓸 시각
    var effectiveDate: Date { at ?? sentAt }

    var isTimer: Bool {
        switch action {
        case .startTimer, .startSession, .pauseTimer, .resumeTimer, .stopTimer: return true
        default: return false
        }
    }

    /// 할 일 명령이 가리키는 그날 일정 id
    var targetID: String? {
        if case .setPlanDone(let planID, let dayKey, _) = action { return "\(planID)_\(dayKey)" }
        return nil
    }

    var message: [String: Any] {
        guard let data = WatchLink.encode(self) else { return [:] }
        return [WatchLink.commandKey: data]
    }

    static func from(_ message: [String: Any]) -> WatchCommand? {
        WatchLink.decode(WatchCommand.self, message[WatchLink.commandKey] as? Data)
    }
}

// MARK: - 보여 주는 글

enum WatchFormat {
    /// 25:00 · 1:05:09
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// 1시간 35분 · 40분 · 0분
    static func duration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)분" }
        return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
    }

    /// 1:35 (좁은 칸용 시:분)
    static func short(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return minutes >= 60 ? String(format: "%d:%02d", minutes / 60, minutes % 60) : "\(minutes)분"
    }
}

// MARK: - 워치 저장 (워치 앱이 받은 마지막 상태 → 위젯도 읽음)

enum WatchSnapshotStore {
    enum Slot: String {
        /// 아이폰에서 받은 그대로 (워치 앱이 다시 켤 때)
        case received = "watchSnapshot.received.v1"
        /// 워치 명령까지 반영한 화면용 (컴플리케이션이 읽음)
        case display = "watchSnapshot.display.v1"
    }

    private static var defaults: UserDefaults { UserDefaults(suiteName: WatchLink.appGroup) ?? .standard }

    static func load(_ slot: Slot = .display) -> WatchSnapshot {
        WatchLink.decode(WatchSnapshot.self, defaults.data(forKey: slot.rawValue)) ?? WatchSnapshot()
    }

    static func save(_ snapshot: WatchSnapshot, _ slot: Slot = .display) {
        guard let data = WatchLink.encode(snapshot) else { return }
        defaults.set(data, forKey: slot.rawValue)
    }
}
