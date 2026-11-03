import Foundation
import SwiftData
import WatchConnectivity

/// 애플 워치 연결: 오늘 상태(공부 시간 · 목표 · 타이머 · 할 일 · 복습 단어)를 워치에 보내고,
/// 워치에서 누른 명령을 기존 타이머 · 플랜 · 단어 복습 규칙으로 저장
/// 워치가 없거나 워치 앱을 설치하지 않았으면 아무것도 하지 않음 (안내 화면 없음)
@MainActor
final class WatchBridge: NSObject {
    static let shared = WatchBridge()

    private var container: ModelContainer?
    private var recent: WatchBridgeLogic.Recent
    private var pushTask: Task<Void, Never>?
    private var saveObserver: NSObjectProtocol?
    private var lastSent: Data?
    private var lastComplicationPush: Date = .distantPast
    private var lastTimerPhase: WatchTimerPhase?
    private let recentKey = "dooit.watch.appliedCommands"

    private override init() {
        recent = WatchBridgeLogic.Recent(UserDefaults.standard.stringArray(forKey: recentKey) ?? [])
        super.init()
    }

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    /// 앱을 켤 때 · 계정을 바꿀 때 (지금 계정 저장소로 연결)
    func start(container: ModelContainer) {
        self.container = container
        guard let session else { return }
        if session.delegate == nil {
            session.delegate = self
            session.activate()
            observeTimer()
            // 플랜 체크 · 단어 · 공부 기록이 저장되면 워치도 새로
            saveObserver = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { _ in
                Task { @MainActor in WatchBridge.shared.setNeedsPush() }
            }
        }
        lastSent = nil
        setNeedsPush()
    }

    /// 조금 기다렸다가 한 번에 보냄 (연달아 바뀔 때)
    func setNeedsPush(after delay: Duration = .milliseconds(600)) {
        pushTask?.cancel()
        pushTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self.push()
        }
    }

    private var canSend: Bool {
        guard let session, session.activationState == .activated else { return false }
        return session.isPaired && session.isWatchAppInstalled
    }

    private func push() {
        guard canSend, let session, container != nil else { return }
        let snapshot = makeSnapshot()
        var comparable = snapshot
        comparable.updatedAt = Date(timeIntervalSince1970: 0)
        let data = WatchLink.encode(comparable)
        let timerChanged = lastTimerPhase != snapshot.timer.phase
        lastTimerPhase = snapshot.timer.phase
        guard data != lastSent else { return }
        lastSent = data
        let message = snapshot.message
        try? session.updateApplicationContext(message)
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else if session.isComplicationEnabled,
                  timerChanged || Date().timeIntervalSince(lastComplicationPush) > 20 * 60,
                  session.remainingComplicationUserInfoTransfers > 5 {
            // 워치 앱이 꺼져 있어도 컴플리케이션이 새 공부 시간을 보이게 (하루 횟수 제한이 있어 아껴 씀)
            lastComplicationPush = Date()
            session.transferCurrentComplicationUserInfo(message)
        }
    }

    // MARK: 타이머 변화 감시

    private func observeTimer() {
        let timer = StudyTimer.shared
        withObservationTracking {
            _ = (timer.phase, timer.title, timer.targetSeconds, timer.startedAt)
        } onChange: {
            Task { @MainActor in
                WatchBridge.shared.setNeedsPush(after: .milliseconds(200))
                WatchBridge.shared.observeTimer()
            }
        }
    }

    // MARK: 상태 만들기

    func makeSnapshot(now: Date = Date()) -> WatchSnapshot {
        var snapshot = WatchSnapshot()
        snapshot.updatedAt = now
        snapshot.dayKey = now.dayKey
        snapshot.accentHex = WidgetSync.accentHex
        snapshot.goalMinutes = UserDefaults.standard.object(forKey: SettingsKey.dailyStudyGoalMinutes) as? Int ?? 180
        snapshot.applied = Array(recent.ids.suffix(30))

        let timer = StudyTimer.shared
        let phase = WatchTimerPhase(rawValue: timer.phase.rawValue) ?? .idle
        snapshot.timer = WatchTimerState.make(phase: phase, title: timer.title, targetSeconds: timer.targetSeconds,
                                              elapsed: timer.elapsed(at: now), now: now)

        guard let context = container?.mainContext else { return snapshot }
        let sessions = (try? context.fetch(FetchDescriptor<StudySession>())) ?? []
        snapshot.savedSeconds = WatchBridgeLogic.todaySeconds(sessions.map { ($0.start, $0.seconds) }, now: now)

        let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        snapshot.plans = plans.occurrences(on: now).map { occurrence in
            WatchPlanItem(
                id: occurrence.id,
                planID: occurrence.plan.id.uuidString,
                dayKey: occurrence.day.dayKey,
                title: occurrence.plan.title,
                time: occurrence.plan.isAllDay ? "종일" : occurrence.start.kr("a h:mm"),
                colorHex: occurrence.plan.category?.colorHex ?? snapshot.accentHex,
                isDone: occurrence.isCompleted,
                isStudy: occurrence.plan.isStudy
            )
        }

        let words = (try? context.fetch(FetchDescriptor<Word>())) ?? []
        snapshot.words = WatchBridgeLogic.reviewDeck(words.map {
            WatchBridgeLogic.WordInfo(id: $0.id.uuidString, term: $0.term, meaning: $0.meaning,
                                      reviewStage: $0.reviewStage, nextReviewAt: $0.nextReviewAt)
        }, now: now)
        return snapshot
    }

    // MARK: 워치 명령 처리

    func apply(_ command: WatchCommand) {
        guard recent.insert(command.id) else { return }
        UserDefaults.standard.set(recent.ids, forKey: recentKey)
        let now = Date()
        let at = WatchBridgeLogic.effectiveTime(sentAt: command.sentAt, now: now)
        let context = container?.mainContext

        switch command.action {
        case .startTimer, .pauseTimer, .resumeTimer, .stopTimer:
            let timer = StudyTimer.shared
            // 워치가 앱을 뒤에서 깨운 경우에도 기록이 저장되게 지금 저장소에 연결
            if let context { timer.attach(context: context) }
            let phase = WatchTimerPhase(rawValue: timer.phase.rawValue) ?? .idle
            switch WatchBridgeLogic.timerAction(for: command.action, phase: phase) {
            case .start(let minutes):
                let study = ((try? context?.fetch(FetchDescriptor<PlanCategory>())) ?? [])
                    .filter(\.isStudy).sorted { $0.sortIndex < $1.sortIndex }
                timer.start(title: "자유 공부", categoryName: study.first?.name ?? "공부",
                            symbol: study.first?.symbol ?? "book.fill", targetMinutes: minutes, at: at)
            case .pause: timer.pause(at: at)
            case .resume: timer.resume(at: at)
            case .stop:
                timer.stop(at: at)
                AmbientSoundPlayer.shared.stop()
            case .none: break
            }
        case .setPlanDone(let planID, let dayKey, let done):
            guard let context, let id = UUID(uuidString: planID), let day = WatchLink.date(fromDayKey: dayKey) else { break }
            let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
            if let plan = plans.first(where: { $0.id == id }),
               WatchBridgeLogic.needsToggle(isCompleted: plan.isCompleted(on: day), wantDone: done) {
                plan.toggleCompleted(on: day)
                try? context.save()
            }
        case .gradeWord(let wordID, let known):
            guard let context, let id = UUID(uuidString: wordID) else { break }
            let words = (try? context.fetch(FetchDescriptor<Word>())) ?? []
            if let word = words.first(where: { $0.id == id }) {
                let state = WatchBridgeLogic.WordState(reviewStage: word.reviewStage, nextReviewAt: word.nextReviewAt,
                                                       correctCount: word.correctCount, wrongCount: word.wrongCount)
                if let next = WatchBridgeLogic.graded(state, known: known, now: at) {
                    word.reviewStage = next.reviewStage
                    word.nextReviewAt = next.nextReviewAt
                    word.correctCount = next.correctCount
                    word.wrongCount = next.wrongCount
                    try? context.save()
                }
            }
        case .refresh:
            break
        }
        if let context, !command.isRefresh { WidgetSync.update(context: context) }
        lastSent = nil
    }

    fileprivate func handle(_ message: [String: Any]) -> [String: Any] {
        if let command = WatchCommand.from(message) { apply(command) }
        lastSent = nil
        setNeedsPush(after: .milliseconds(300))
        return makeSnapshot().message
    }
}

private extension WatchCommand {
    var isRefresh: Bool { action == .refresh }
}

// MARK: - WCSessionDelegate (아무 스레드에서나 불려서 메인으로 넘김)

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in WatchBridge.shared.setNeedsPush() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // 다른 워치로 바꾸면 새 워치와 다시 연결
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            WatchBridge.shared.lastSent = nil
            WatchBridge.shared.setNeedsPush()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in
            WatchBridge.shared.lastSent = nil
            WatchBridge.shared.setNeedsPush()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in _ = WatchBridge.shared.handle(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in replyHandler(WatchBridge.shared.handle(message)) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in _ = WatchBridge.shared.handle(userInfo) }
    }
}
