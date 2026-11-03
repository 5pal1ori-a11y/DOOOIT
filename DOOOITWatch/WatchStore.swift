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

    @ObservationIgnored private var outbox: [WatchCommand] = []
    @ObservationIgnored private let pendingKey = "watch.pendingCommands"
    @ObservationIgnored private var goalTask: Task<Void, Never>?
    @ObservationIgnored private var cheeredGoal: Date?
    @ObservationIgnored private var demo = false

    private override init() {
        received = WatchSnapshotStore.load(.received)
        pending = WatchLink.decode([WatchCommand].self, UserDefaults.standard.data(forKey: "watch.pendingCommands")) ?? []
        snapshot = WatchSnapshot()
        super.init()
        recompute()
    }

    func activate() {
        #if DEBUG
        if let demo = WatchDemo.snapshot {
            self.demo = true
            received = demo
            pending = []
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
        let changedForWidget = display.savedSeconds != snapshot.savedSeconds || display.goalMinutes != snapshot.goalMinutes
            || display.timer != snapshot.timer || display.accentHex != snapshot.accentHex || display.dayKey != snapshot.dayKey
        snapshot = display
        guard !demo else { return }
        WatchSnapshotStore.save(display, .display)
        if changedForWidget { WidgetCenter.shared.reloadAllTimelines() }
        scheduleGoalCheer()
    }

    // MARK: 명령 보내기

    func send(_ action: WatchCommand.Action) {
        let command = WatchCommand(action)
        if action != .refresh {
            pending.append(command)
            recompute()
        }
        guard !demo else { return }
        deliver(command)
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

    // MARK: 목표 달성 진동

    /// 화면이 켜져 있으면 바로 진동, 손목을 내려도 알림으로 진동
    private func scheduleGoalCheer() {
        goalTask?.cancel()
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["watch.goal"])
        guard let goal = snapshot.timer.goalDate, goal > Date() else { return }
        goalTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(goal.timeIntervalSinceNow))
            guard !Task.isCancelled, WatchStore.shared.snapshot.timer.goalDate == goal,
                  WatchStore.shared.cheeredGoal != goal else { return }
            WatchStore.shared.cheeredGoal = goal
            WKInterfaceDevice.current().play(.success)
        }
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "목표 달성!"
            content.body = "오늘도 잘했어요"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, goal.timeIntervalSinceNow), repeats: false)
            center.add(UNNotificationRequest(identifier: "watch.goal", content: content, trigger: trigger))
        }
    }

    /// 목표를 정하고 시작할 때 한 번만 알림 허락을 물음
    func askNotificationIfNeeded() {
        guard !demo else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            Task { @MainActor in WatchStore.shared.scheduleGoalCheer() }
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
