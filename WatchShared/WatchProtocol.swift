import Foundation

// 아이폰 ↔ 애플 워치가 주고받는 자료 (WatchConnectivity)
// 아이폰 앱 · 워치 앱 · 워치 위젯(컴플리케이션)이 같이 쓰는 파일이라 Foundation만 씀
// - 아이폰 → 워치: WatchSnapshot (오늘 공부 시간 · 목표 · 타이머 · 할 일 · 복습 단어)
// - 워치 → 아이폰: WatchCommand (타이머 시작/멈춤/끝, 할 일 체크, 단어 알아요/몰라요)
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
}

struct WatchWordItem: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var term: String
    var meaning: String
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

    var isEmpty: Bool { dayKey.isEmpty }

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
    func forToday(_ date: Date) -> WatchSnapshot {
        guard !isEmpty, dayKey != WatchLink.dayKey(date) else { return self }
        var copy = self
        copy.savedSeconds = 0
        copy.plans = []
        copy.words = []
        copy.dayKey = WatchLink.dayKey(date)
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
            let at = command.sentAt
            switch command.action {
            case .startTimer(let minutes):
                guard !s.timer.isActive else { continue }
                s.timer = WatchTimerState(phase: .running, title: "자유 공부", targetSeconds: minutes.map { $0 * 60 },
                                          runningSince: at, pausedElapsed: 0)
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
            case .gradeWord(let wordID, _):
                s.words.removeAll { $0.id == wordID }
            case .refresh:
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

// MARK: - 명령

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
    }

    var id: String = UUID().uuidString
    var sentAt: Date = Date()
    var action: Action

    init(_ action: Action, id: String = UUID().uuidString, sentAt: Date = Date()) {
        self.action = action
        self.id = id
        self.sentAt = sentAt
    }

    var isTimer: Bool {
        switch action {
        case .startTimer, .pauseTimer, .resumeTimer, .stopTimer: return true
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
