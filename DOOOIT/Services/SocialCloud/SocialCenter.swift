import Foundation
import Observation
import SwiftData
import UIKit

/// 친구 · 그룹의 앱 쪽 관리자: 저장 · 내 공부 상태 올리기 (타이머를 절대 막지 않음)
/// - 타이머가 시작 · 멈춤 · 일시정지할 때 timerChanged()만 부르면 됨. 기능을 안 켰으면 아무 일도 안 함.
/// - 올리는 일은 뒤에서(await): 시작/멈춤은 바로(5초 간격), 공부 중에는 60초마다, 합계만 바뀌면 20초 모아서
/// - 인터넷 문제는 점점 길게 쉬었다 다시, 너무 자주 보냈다는 답은 알려 준 시간만큼 기다림
@MainActor
@Observable
final class SocialCenter {
    static let shared = SocialCenter()

    /// 이 기기의 친구 · 그룹 상태 (화면이 이 값을 봄)
    private(set) var state = SocialState()
    private(set) var accountStatus: SocialAccountStatus = .available
    /// 내 상태를 못 올리고 있는지 (화면에 작게 알림)
    private(set) var publishFailing = false

    @ObservationIgnored private var _engine: SocialEngine?
    @ObservationIgnored private var backendOverride: SocialBackend?
    @ObservationIgnored private let store = SocialStateStore()
    @ObservationIgnored private var policy = PublishPolicy()
    @ObservationIgnored private var lastSnapshot: PublishedSnapshot?
    @ObservationIgnored private var scheduled: (task: Task<Void, Never>, fireAt: Date)?
    @ObservationIgnored private var heartbeat: Task<Void, Never>?
    @ObservationIgnored private var inFlight = false
    @ObservationIgnored private var again: PublishReason?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var appActive = true
    @ObservationIgnored private var observers: [Task<Void, Never>] = []

    init() {
        state = store.load()
    }

    var isEnabled: Bool { state.enabled }

    /// 화면이 쓰는 엔진 (처음 쓸 때 만듦: 기능을 안 쓰면 CloudKit도 건드리지 않음)
    var engine: SocialEngine {
        if let _engine { return _engine }
        let e = SocialEngine(backend: backendOverride ?? CloudKitSocialBackend(), state: state)
        e.onChange = { [weak self] new in
            guard let self else { return }
            self.state = new
            self.store.save(new)
        }
        _engine = e
        return e
    }

    // MARK: 시작 · 계정

    /// 저장소를 연결 (계정을 바꿀 때마다 부름: 그 계정의 친구 상태를 다시 읽음)
    func attach(context: ModelContext) {
        self.context = context
        reloadFromStore()
        startObservingApp()
    }

    func reloadFromStore() {
        scheduled?.task.cancel(); scheduled = nil
        heartbeat?.cancel(); heartbeat = nil
        policy = PublishPolicy()
        lastSnapshot = nil
        state = store.load()
        _engine?.replaceState(state)
        if state.enabled { updateHeartbeat(); request(.stateChange) }
    }

    func refreshAccountStatus() async {
        accountStatus = await engine.backend.accountStatus()
    }

    private func startObservingApp() {
        guard observers.isEmpty else { return }
        observers.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                self?.appActiveChanged(true)
            }
        })
        observers.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.willResignActiveNotification) {
                self?.appActiveChanged(false)
            }
        })
    }

    private func appActiveChanged(_ active: Bool) {
        appActive = active
        guard state.enabled else { return }
        updateHeartbeat()
        if active {
            request(.stateChange)
            Task { await engine.flushPendingReports() }
        }
    }

    // MARK: 켜기 · 끄기

    func setUp(nickname: String) async throws {
        let now = Date()
        try await engine.setUp(nickname: nickname, totals: currentTotals(now).totals)
        policy = PublishPolicy()
        lastSnapshot = nil
        updateHeartbeat()
        request(.stateChange)
    }

    func deleteEverything() async throws {
        try await engine.deleteEverything()
        scheduled?.task.cancel(); scheduled = nil
        heartbeat?.cancel(); heartbeat = nil
        lastSnapshot = nil
        publishFailing = false
    }

    /// 닉네임 바꾸기 · 코드 다시 만들기도 같은 엔진을 쓰되, 올리는 값에 지금 시간을 넣어 줌
    func setNickname(_ raw: String) async throws {
        try await engine.setNickname(raw)
        lastSnapshot = nil
    }

    func regenerateFriendCode() async throws {
        try await engine.regenerateFriendCode()
    }

    /// 내 공부 상태 보여주기 켜기/끄기: 바로 올려 보고, 못 올리면 되돌림 (숨긴 줄 알았는데 안 숨겨진 상태를 막으려고)
    func setShowStatus(_ on: Bool) async throws {
        let previous = state.showStatus
        engine.setShowStatus(on)
        do {
            let now = Date()
            let (totals, since) = currentTotals(now)
            try await engine.publish(totals: totals, studyingSince: since)
            lastSnapshot = nil
            request(.stateChange)
        } catch {
            engine.setShowStatus(previous)
            throw error
        }
    }

    // MARK: 타이머에서 부름 (바로 돌아옴)

    func timerChanged() {
        guard state.enabled else { return }
        updateHeartbeat()
        request(.stateChange)
    }

    /// 화면이 열릴 때 내 상태도 최신으로
    func screenOpened() {
        guard state.enabled else { return }
        request(.totalChange)
    }

    // MARK: 올리기

    private func request(_ reason: PublishReason) {
        guard state.enabled else { return }
        let now = Date()
        let delay = policy.delay(for: reason, now: now)
        let fireAt = now.addingTimeInterval(delay)
        if let scheduled, scheduled.fireAt <= fireAt, !scheduled.task.isCancelled { return }
        scheduled?.task.cancel()
        let task = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            await self?.perform(reason)
        }
        scheduled = (task, fireAt)
    }

    private func updateHeartbeat() {
        let running = StudyTimer.shared.phase == .running && appActive && state.enabled
        if running {
            guard heartbeat == nil else { return }
            heartbeat = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { return }
                    self?.request(.heartbeat)
                }
            }
        } else {
            heartbeat?.cancel()
            heartbeat = nil
        }
    }

    private func perform(_ reason: PublishReason) async {
        scheduled = nil
        guard state.enabled else { return }
        // 이미 올리는 중이면 끝난 뒤 한 번 더
        if inFlight { again = reason; return }
        inFlight = true
        defer { inFlight = false }

        let now = Date()
        let (totals, since) = currentTotals(now)
        let candidate = engine.makeProfile(totals: totals, studyingSince: since)
        let snapshot = PublishedSnapshot(studying: candidate.studyingSince != nil, todaySeconds: candidate.todaySeconds,
                                         weekSeconds: candidate.weekSeconds, todayKey: candidate.todayKey,
                                         hidden: candidate.isHidden, nickname: candidate.nickname)
        if policy.shouldSend(snapshot, last: lastSnapshot, reason: reason) {
            do {
                try await engine.publish(totals: totals, studyingSince: since)
                policy.recordSuccess(at: Date())
                lastSnapshot = snapshot
                publishFailing = false
            } catch {
                publishFailing = true
                let err = (error as? SocialError) ?? .network
                if policy.recordFailure(err, at: Date()) != nil { request(.retry) }
            }
        }
        if let next = again {
            again = nil
            request(next)
        }
    }

    /// 오늘 · 이번 주 공부 시간 (저장된 기록 + 지금 하는 공부)과 공부 중이면 시작한 것으로 치는 때
    func currentTotals(_ now: Date) -> (totals: SocialClock.Totals, studyingSince: Date?) {
        var sessions: [(start: Date, seconds: Int)] = []
        if let context {
            var descriptor = FetchDescriptor<StudySession>(sortBy: [SortDescriptor(\.start, order: .reverse)])
            descriptor.fetchLimit = 600
            // 자정을 넘긴 12시간짜리 기록까지 겹칠 수 있어서 한 주 시작보다 조금 앞까지 봄
            let from = SocialClock.weekRange(now).start.addingTimeInterval(-13 * 3600)
            for s in (try? context.fetch(descriptor)) ?? [] {
                if s.start < from { break }
                sessions.append((s.start, s.seconds))
            }
        }
        let timer = StudyTimer.shared
        var since: Date?
        if timer.phase != .idle {
            let elapsed = timer.elapsed(at: now)
            if elapsed >= 1 { sessions.append((now.addingTimeInterval(-elapsed), Int(elapsed))) }
            if timer.phase == .running { since = now.addingTimeInterval(-elapsed) }
        }
        return (SocialClock.totals(sessions: sessions, now: now), since)
    }

    #if DEBUG
    /// 화면 사진용: 가짜 클라우드와 예시 상태로 바꿈 (CloudKit · 저장 없음)
    func installDemo(backend: SocialBackend, state demo: SocialState) {
        backendOverride = backend
        state = demo
        let e = SocialEngine(backend: backend, state: demo)
        e.onChange = { [weak self] new in self?.state = new }
        _engine = e
        accountStatus = .available
    }
    #endif
}
