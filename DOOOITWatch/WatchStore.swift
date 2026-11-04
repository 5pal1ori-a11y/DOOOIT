import Foundation
import Observation
import UserNotifications
import WatchConnectivity
import WatchKit
import WidgetKit

/// 워치 쪽 상태: 아이폰이 보낸 마지막 상태 + 아직 처리 안 된 내 명령을 합쳐서 보여 줌
@MainActor
@Observable
final class WatchStore: NSObject {
    static let shared = WatchStore()

    /// 아이폰에서 받은 그대로
    private(set) var received: WatchSnapshot
    /// 보낸 뒤 아이폰이 아직 처리하지 않은 명령
    private(set) var pending: [WatchCommand]
    /// 화면에 보이는 상태
    private(set) var snapshot: WatchSnapshot
    /// 뽀모도로 · 휴식 (워치에서만)
    private(set) var focus: WatchFocusCycle?

    @ObservationIgnored private var outbox: [WatchCommand] = []
    @ObservationIgnored private let pendingKey = "watch.pendingCommands"
    @ObservationIgnored private let focusKey = "watch.focusCycle"
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    /// 이미 진동한 일 (같은 일로 두 번 울리지 않게)
    @ObservationIgnored private var cheered: Set<String> = []
    @ObservationIgnored private var lastDigest: Data?
    @ObservationIgnored private var demo = false

    private override init() {
        received = WatchSnapshotStore.load(.received)
        pending = WatchLink.decode([WatchCommand].self, UserDefaults.standard.data(forKey: "watch.pendingCommands")) ?? []
        focus = WatchLink.decode(WatchFocusCycle.self, UserDefaults.standard.data(forKey: "watch.focusCycle"))
        snapshot = WatchSnapshot()
        super.init()
        recompute()
    }

    func activate() {
        #if DEBUG
        if let demo = WatchDemo.snapshot {
            self.demo = true
            received = demo
            pending = WatchDemo.pending
            focus = WatchDemo.focus
            recompute()
            return
        }
        #endif
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil {
            session.delegate = self
            session.activate()
        } else if session.activationState == .activated {
            sessionReady(session)
        }
    }

    // MARK: 받은 상태

    fileprivate func receive(_ message: [String: Any]) {
        guard let incoming = WatchSnapshot.from(message), incoming.version >= 1 else { return }
        // 늦게 도착한 옛날 상태는 버림
        guard incoming.updatedAt >= received.updatedAt else { return }
        received = incoming
        WatchSnapshotStore.save(incoming, .received)
        recompute()
    }

    private func recompute() {
        let now = Date()
        pending = received.stillPending(pending, now: now)
        UserDefaults.standard.set(WatchLink.encode(pending), forKey: pendingKey)
        let display = received.applying(pending).forToday(now)
        snapshot = display
        tick(now: now)
        guard !demo else { return }
        WatchSnapshotStore.save(snapshot, .display)
        // 컴플리케이션에 보이는 것이 바뀔 때만 다시 그림
        let digest = snapshot.complicationDigest
        if digest != lastDigest {
            lastDigest = digest
            WidgetCenter.shared.reloadAllTimelines()
        }
        scheduleEvents()
    }

    // MARK: 명령 보내기

    func send(_ action: WatchCommand.Action, at: Date? = nil) {
        let command = WatchCommand(action, at: at)
        if action != .refresh {
            pending.append(command)
            recompute()
        }
        guard !demo else { return }
        deliver(command)
    }

    /// 보낸 명령이 아직 처리 중인지 (모티 답 기다리기 등)
    func isPending(_ id: String) -> Bool { pending.contains { $0.id == id } }

    /// 모티에게 묻기 (답은 다음 상태에 같이 옴). 보낸 명령 id
    @discardableResult
    func ask(_ text: String) -> String {
        let command = WatchCommand(.ask(text: text))
        pending.append(command)
        recompute()
        if !demo { deliver(command) }
        return command.id
    }

    private func deliver(_ command: WatchCommand) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            outbox.append(command)
            return
        }
        let message = command.message
        if session.isReachable {
            session.sendMessage(message, replyHandler: { reply in
                Task { @MainActor in WatchStore.shared.receive(reply) }
            }, errorHandler: { _ in
                // 바로 못 보내면 줄 세워 두고 나중에 꼭 전달 (아이폰은 같은 명령을 두 번 처리하지 않음)
                guard command.action != .refresh else { return }
                Task { @MainActor in WCSession.default.transferUserInfo(message) }
            })
        } else if command.action != .refresh {
            session.transferUserInfo(message)
        }
    }

    fileprivate func sessionReady(_ session: WCSession) {
        receive(session.receivedApplicationContext)
        let queued = outbox
        outbox = []
        queued.forEach(deliver)
        deliver(WatchCommand(.refresh))
    }

    /// 화면을 다시 볼 때
    func refresh() {
        recompute()
        guard !demo, WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        deliver(WatchCommand(.refresh))
    }

    // MARK: 타이머 시작 (자유 · 할 일 · 뽀모도로 · 휴식)

    func start(minutes: Int?, plan: WatchPlanItem? = nil) {
        if focus != nil { setFocus(nil) }
        if minutes != nil { askNotificationIfNeeded() }
        send(.startSession(WatchStart(targetMinutes: minutes, planID: plan?.planID, dayKey: plan?.dayKey, title: nil)))
        WatchHaptics.play(.start)
    }

    func startPomodoro() {
        var cycle = WatchFocusCycle()
        cycle.focusMinutes = WatchPrefs.focusMinutes
        cycle.restMinutes = WatchPrefs.restMinutes
        cycle.longRestMinutes = max(WatchPrefs.restMinutes * 3, 15)
        setFocus(cycle)
        askNotificationIfNeeded()
        send(.startSession(WatchStart(targetMinutes: cycle.focusMinutes, title: "뽀모도로")))
        WatchHaptics.play(.start)
    }

    /// 쉬기만 (공부 기록 없음)
    func startRest(minutes: Int) {
        guard !snapshot.timer.isActive else { return }
        setFocus(.rest(minutes: minutes, now: Date()))
        askNotificationIfNeeded()
        WatchHaptics.play(.start)
    }

    func nextFocus() {
        guard var cycle = focus else { return }
        cycle.nextFocus()
        setFocus(cycle)
        send(.startSession(WatchStart(targetMinutes: cycle.focusMinutes, title: "뽀모도로")))
        WatchHaptics.play(.start)
    }

    func skipRest() {
        guard var cycle = focus else { return }
        if cycle.restOnly {
            setFocus(nil)
        } else {
            cycle.skipRest()
            setFocus(cycle)
        }
        WatchHaptics.play(.click)
    }

    /// 끝내고 기록 (뽀모도로도 같이 끝)
    func stop() {
        setFocus(nil)
        if snapshot.timer.isActive { send(.stopTimer) }
        WatchHaptics.play(.stop)
    }

    private func setFocus(_ cycle: WatchFocusCycle?) {
        focus = cycle
        guard !demo else { return }
        UserDefaults.standard.set(cycle.flatMap { WatchLink.encode($0) }, forKey: focusKey)
    }

    // MARK: 시간에 따라 일어나는 일 (집중 끝 · 휴식 끝 · 목표 달성 · 30분마다)

    /// 뽀모도로 단계 넘기기
    private func tick(now: Date) {
        guard var cycle = focus else { return }
        let event = cycle.update(timer: snapshot.timer, now: now)
        guard let event else { return }
        switch event {
        case .focusDone(let end):
            setFocus(cycle)
            cheer("watch.goal@\(Int(end.timeIntervalSince1970))", .success)
            // 집중이 끝난 시각으로 기록 (늦게 열어도 정확히 집중한 만큼만)
            send(.stopTimer, at: end)
        case .restDone:
            setFocus(cycle.restOnly ? nil : cycle)
            cheer("watch.rest@\(Int((cycle.restUntil ?? now).timeIntervalSince1970))", .notification)
        case .cancelled:
            setFocus(nil)
        }
    }

    private func cheer(_ key: String, _ type: WKHapticType) {
        guard !demo, cheered.insert(key).inserted else { return }
        WatchHaptics.play(type)
    }

    private struct Upcoming {
        var id: String
        var date: Date
        var title: String
        var body: String
        var haptic: WKHapticType
        /// 손목을 내려도 알림으로
        var notify = true
    }

    private func upcomingEvents(now: Date) -> [Upcoming] {
        let timer = snapshot.timer
        var list: [Upcoming] = []
        if let cycle = focus {
            switch cycle.stage {
            case .focus:
                if let goal = timer.goalDate {
                    list.append(Upcoming(id: "watch.goal", date: goal, title: "집중 끝!", body: "\(cycle.restLength)분 쉬어요", haptic: .success))
                    let restEnd = goal.addingTimeInterval(Double(cycle.restLength) * 60)
                    list.append(Upcoming(id: "watch.rest", date: restEnd, title: "휴식 끝", body: "다시 집중해요", haptic: .notification))
                }
            case .rest:
                if let until = cycle.restUntil {
                    list.append(Upcoming(id: "watch.rest", date: until, title: "휴식 끝",
                                         body: cycle.restOnly ? "다시 공부해요" : "다시 집중해요", haptic: .notification))
                }
            case .ready:
                break
            }
        } else if let goal = timer.goalDate {
            list.append(Upcoming(id: "watch.goal", date: goal, title: "목표 달성!", body: "오늘도 잘했어요", haptic: .success))
        }
        if let daily = snapshot.dailyGoalDate(at: now), !list.contains(where: { abs($0.date.timeIntervalSince(daily)) < 60 }) {
            list.append(Upcoming(id: "watch.daily", date: daily, title: "오늘 목표 달성!",
                                 body: WatchFormat.duration(snapshot.goalMinutes * 60), haptic: .success))
        }
        // 30분마다 살짝 (화면이 켜져 있을 때만)
        if WatchPrefs.milestones, timer.phase == .running, let since = timer.runningSince {
            let next = (floor(now.timeIntervalSince(since) / 1_800) + 1) * 1_800
            list.append(Upcoming(id: "watch.mile", date: since.addingTimeInterval(next), title: "", body: "", haptic: .directionUp, notify: false))
        }
        return list.filter { $0.date > now }
    }

    private func scheduleEvents() {
        eventTask?.cancel()
        let now = Date()
        let events = upcomingEvents(now: now)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["watch.goal", "watch.rest", "watch.daily"])
        if WatchPrefs.haptics {
            let alerts = events.filter(\.notify).map { ($0.id, $0.date, $0.title, $0.body) }
            center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else { return }
                for (id, date, title, body) in alerts {
                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.body = body
                    content.sound = .default
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
                    center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
            }
        }
        guard let first = events.min(by: { $0.date < $1.date }) else { return }
        // 화면이 켜져 있으면 바로 진동
        eventTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(0.2, first.date.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            let store = WatchStore.shared
            store.cheer("\(first.id)@\(Int(first.date.timeIntervalSince1970))", first.haptic)
            store.recompute()
        }
    }

    /// 목표를 정하고 시작할 때 한 번만 알림 허락을 물음
    func askNotificationIfNeeded() {
        guard !demo else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            Task { @MainActor in WatchStore.shared.scheduleEvents() }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in WatchStore.shared.sessionReady(session) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in WatchStore.shared.receive(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in WatchStore.shared.receive(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in WatchStore.shared.receive(userInfo) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in WatchStore.shared.refresh() }
    }
}
