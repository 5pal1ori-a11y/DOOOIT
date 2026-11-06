import Observation
import SwiftUI
import UIKit

/// AI 순공부 측정을 이끄는 곳: 카메라 → 분석 → StudyPresenceEngine → 화면에 보일 값
/// - 공부 타이머와 같이 움직임: 타이머가 멈추면(일시정지) 카메라도 멈추고, 끝나면 결과를 저장
/// - 앱이 뒤로 가면 iOS가 카메라를 끊어서 그동안은 세지 않음 (돌아오면 이어서)
/// - 측정하는 동안 화면이 꺼지지 않게 함
/// - 영상 · 사진은 저장하지 않음. 저장하는 것은 초 단위 숫자(PresenceStore)뿐
@MainActor
@Observable
final class StudyPresenceMonitor {
    static let shared = StudyPresenceMonitor()

    enum Status: Equatable {
        /// 꺼져 있음
        case off
        /// 가이드 화면에서 미리보기 중 (세지 않음)
        case previewing
        /// 측정 중
        case measuring
        /// 타이머 일시정지 중
        case paused
        /// 앱이 뒤로 갔거나 카메라가 끊김
        case suspended
        /// 쓸 수 없음 (권한 · 카메라 없음)
        case unavailable(String)
    }

    // 설정 열쇠
    static let enabledKey = "timer.aiMeasure"
    static let cameraKey = "timer.aiMeasure.camera"
    static let flipKey = "timer.aiMeasure.flip"
    /// 측정 중에 타이머 화면에서 카메라 화면을 보여 줄지 (기본 켬)
    static let liveKey = "timer.aiMeasure.live"

    /// 앱이 이 시간보다 오래 뒤에 있다 돌아오면 카메라를 저절로 켜지 않고 눌러서 켜게 함 (초)
    static let maxBackgroundResume: TimeInterval = 10 * 60

    private(set) var status: Status = .off
    private(set) var state: StudyPresenceState = .waiting
    private(set) var netSeconds = 0
    private(set) var measuredSeconds = 0
    /// 가이드 화면의 미리보기 그림과 찾은 점 (측정 중에는 비어 있음)
    private(set) var previewImage: UIImage?
    private(set) var previewFrame: PresenceFrame?
    private(set) var previewObservation: FrameObservation?
    /// 가이드 화면을 사진 찍을 때(DEBUG)만 켜는 가짜 장면
    private(set) var isDemo = false

    /// 이번 공부의 측정 시작 시각 (측정 중이 아니면 nil)
    private(set) var sessionStart: Date?
    var isSessionActive: Bool { sessionStart != nil }

    @ObservationIgnored private let camera = PresenceCameraController()
    @ObservationIgnored private let store = PresenceStore()
    @ObservationIgnored private var engine = StudyPresenceEngine()
    @ObservationIgnored private var aggregator = PresenceAggregator()
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var backgroundedAt: Date?
    @ObservationIgnored private var lastLiveSave = Date.distantPast
    @ObservationIgnored private var savedIdleTimer: Bool?
    @ObservationIgnored private var previewRequested = false

    private init() {
        camera.onObservation = { [weak self] observation, frame, time in
            Task { @MainActor in self?.receive(observation, frame, at: time) }
        }
        camera.onPreview = { [weak self] image in
            Task { @MainActor in self?.receivePreview(image) }
        }
        camera.onInterruption = { [weak self] interrupted in
            Task { @MainActor in self?.cameraInterrupted(interrupted) }
        }
    }

    // MARK: 설정

    var cameraPosition: PresenceCameraPosition {
        PresenceCameraPosition(rawValue: UserDefaults.standard.string(forKey: Self.cameraKey) ?? "") ?? .back
    }

    var layout: PresenceLayout {
        PresenceLayout.make(flipped: UserDefaults.standard.bool(forKey: Self.flipKey))
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    private(set) var showLive: Bool = UserDefaults.standard.object(forKey: StudyPresenceMonitor.liveKey) as? Bool ?? true

    /// 측정 중 카메라 화면 보이기 · 숨기기 (숨기면 화면용 그림을 만들지 않아 배터리도 아낌)
    func setLive(_ on: Bool) {
        showLive = on
        UserDefaults.standard.set(on, forKey: Self.liveKey)
        camera.setPreview(on && status == .measuring)
        if !on { previewImage = nil; previewFrame = nil; previewObservation = nil }
    }

    /// 미리보기 중 카메라나 좌우를 바꿨을 때 다시 반영
    func settingsChanged() {
        guard status == .previewing || status == .measuring else { return }
        camera.setLayout(layout)
        Task { await restartCamera(preview: status == .previewing) }
    }

    // MARK: 가이드 화면 (미리보기)

    func startPreview() async {
        previewRequested = true
        guard !isSessionActive, !isDemo else { return }
        #if DEBUG
        if UIShot.isActive { return }
        #endif
        guard PresenceCameraController.hasCamera(cameraPosition) else {
            status = .unavailable(PresenceCameraError.noCamera.message)
            return
        }
        guard await PresenceCameraController.requestAccess() else {
            status = .unavailable(PresenceCameraError.denied.message)
            return
        }
        await restartCamera(preview: true)
    }

    func stopPreview() {
        previewRequested = false
        guard !isSessionActive else { return }
        previewImage = nil
        previewFrame = nil
        previewObservation = nil
        guard status == .previewing || status.isUnavailable else { return }
        camera.stop()
        status = .off
        releaseScreen()
    }

    // MARK: 측정

    /// 공부를 시작할 때 (설정에서 켜 둔 경우). startedAt은 공부 기록의 시작 시각과 같아야 함
    func begin(startedAt: Date) {
        if isSessionActive { _ = finish(totalSeconds: nil) }
        engine = StudyPresenceEngine()
        aggregator = PresenceAggregator()
        sessionStart = startedAt
        state = .waiting
        netSeconds = 0
        measuredSeconds = 0
        previewImage = nil
        previewFrame = nil
        startTicker()
        observeApp()
        Task { await launchCamera() }
    }

    /// 앱이 다시 켜졌는데 공부 중이고 이어 갈 측정이 있으면 이어서 (카메라는 사용자가 앱을 열었을 때만)
    func resumeIfNeeded() {
        let timer = StudyTimer.shared
        guard isEnabled, timer.isActive, !isSessionActive, let start = timer.startedAt,
              let live = store.live(), PresenceStore.key(for: live.startedAt) == PresenceStore.key(for: start) else { return }
        engine = StudyPresenceEngine(resuming: live.totals)
        aggregator = PresenceAggregator()
        sessionStart = start
        state = .waiting
        netSeconds = live.netSeconds
        measuredSeconds = live.measuredSeconds
        startTicker()
        observeApp()
        Task { await launchCamera() }
    }

    /// 공부를 마칠 때: 결과를 저장하고 카메라를 끔. totalSeconds는 타이머의 전체 시간 (결과가 이보다 길지 않게)
    @discardableResult
    func finish(totalSeconds: Int?) -> PresenceSummary? {
        guard let start = sessionStart else { return nil }
        let summary = engine.summary(startedAt: start, totalSeconds: totalSeconds)
        if summary.measuredSeconds >= 10 { store.save(summary) }
        store.clearLive()
        endSession()
        return summary
    }

    /// 사용자가 눌러서 다시 켜기 (오래 뒤에 갔다 와서 멈춰 있을 때)
    func resumeNow() {
        guard isSessionActive, status == .suspended || status.isUnavailable else { return }
        Task { await launchCamera() }
    }

    private func endSession() {
        ticker?.cancel()
        ticker = nil
        sessionStart = nil
        camera.stop()
        previewImage = nil; previewFrame = nil; previewObservation = nil
        status = .off
        state = .waiting
        releaseScreen()
        removeAppObservers()
    }

    // MARK: 카메라

    private func launchCamera() async {
        guard isSessionActive else { return }
        #if DEBUG
        if UIShot.isActive { return }
        #endif
        guard PresenceCameraController.hasCamera(cameraPosition) else {
            status = .unavailable(PresenceCameraError.noCamera.message)
            return
        }
        guard await PresenceCameraController.requestAccess() else {
            status = .unavailable(PresenceCameraError.denied.message)
            return
        }
        aggregator.reset()
        camera.resetTracking()
        do {
            try await camera.start(position: cameraPosition, layout: layout, preview: showLive)
            guard isSessionActive else { camera.stop(); return }
            status = StudyTimer.shared.phase == .paused ? .paused : .measuring
            if status == .paused { camera.stop() } else { keepScreenOn() }
        } catch let error as PresenceCameraError {
            status = .unavailable(error.message)
        } catch {
            status = .unavailable(PresenceCameraError.failed.message)
        }
    }

    private func restartCamera(preview: Bool) async {
        do {
            try await camera.start(position: cameraPosition, layout: layout, preview: preview)
            if preview, !isSessionActive {
                status = .previewing
                keepScreenOn()
            }
        } catch let error as PresenceCameraError {
            status = .unavailable(error.message)
        } catch {
            status = .unavailable(PresenceCameraError.failed.message)
        }
    }

    private func cameraInterrupted(_ interrupted: Bool) {
        guard isSessionActive else { return }
        if interrupted {
            if status == .measuring { status = .suspended }
        } else if status == .suspended, backgroundedAt == nil {
            status = .measuring
            aggregator.reset()
            camera.resetTracking()
        }
    }

    // MARK: 프레임 받기

    private func receive(_ observation: FrameObservation, _ frame: PresenceFrame, at time: TimeInterval) {
        switch status {
        case .previewing:
            previewFrame = frame
            previewObservation = observation
        case .measuring:
            guard isSessionActive, StudyTimer.shared.phase == .running else { return }
            if showLive { previewFrame = frame; previewObservation = observation }
            if let sample = aggregator.add(observation, at: time) {
                engine.feed(sample)
                state = engine.state
                netSeconds = engine.netSeconds
                measuredSeconds = engine.measuredSeconds
            }
        default:
            break
        }
    }

    private func receivePreview(_ image: UIImage) {
        guard status == .previewing || (status == .measuring && showLive) else { return }
        previewImage = image
    }

    // MARK: 1초마다: 타이머와 맞추기 · 중간 저장

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let start = sessionStart else { return }
        let timer = StudyTimer.shared
        switch timer.phase {
        case .idle:
            // 시계나 다른 곳에서 타이머가 끝남
            _ = finish(totalSeconds: nil)
            return
        case .paused:
            if status == .measuring {
                status = .paused
                camera.stop()
                previewImage = nil
                releaseScreen()
            }
        case .running:
            if status == .paused {
                Task { await launchCamera() }
            }
        }
        if Date().timeIntervalSince(lastLiveSave) >= 10 {
            lastLiveSave = Date()
            store.saveLive(engine.summary(startedAt: start))
        }
    }

    // MARK: 앱 앞뒤 · 화면 켜 두기

    private func observeApp() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.appWentToBackground() }
        })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.appBecameActive() }
        })
    }

    private func removeAppObservers() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
    }

    private func appWentToBackground() {
        backgroundedAt = Date()
        if let start = sessionStart { store.saveLive(engine.summary(startedAt: start)) }
        guard status == .measuring || status == .previewing else { return }
        camera.stop()
        previewImage = nil
        status = isSessionActive ? .suspended : .off
        releaseScreen()
    }

    private func appBecameActive() {
        let away = backgroundedAt.map { Date().timeIntervalSince($0) }
        backgroundedAt = nil
        guard isSessionActive, status == .suspended else { return }
        // 오래 뒤에 있다 왔으면 카메라가 저절로 켜지지 않게 눌러서 켜도록
        if let away, away > Self.maxBackgroundResume { return }
        Task { await launchCamera() }
    }

    private func keepScreenOn() {
        if savedIdleTimer == nil { savedIdleTimer = UIApplication.shared.isIdleTimerDisabled }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func releaseScreen() {
        guard let saved = savedIdleTimer else { return }
        UIApplication.shared.isIdleTimerDisabled = saved
        savedIdleTimer = nil
    }

    // MARK: 지금 보이는 값

    /// 타이머 위에 보이는 칩 글
    var chipText: String {
        switch status {
        case .unavailable(let message): return message.loc
        case .suspended: return L("측정 멈춤 · 눌러서 켜기")
        case .paused: return L("일시정지")
        default: return PresenceText.chipL(state: state, netSeconds: netSeconds)
        }
    }

    /// 칩 색: 공부 중이면 초록, 자리 비움 · 딴짓이면 주황 등
    var chipColor: Color {
        switch status {
        case .unavailable, .suspended: return Palette.warning
        case .paused: return Color(white: 0.55)
        default:
            switch state {
            case .studying: return Color(hex: "#34C759")
            case .waiting: return Color(white: 0.6)
            case .still: return Palette.warning
            case .distracted: return Palette.peach
            case .away: return Palette.danger
            }
        }
    }

    #if DEBUG
    /// 화면 사진용: 카메라 없이 가짜 값만 보여 줌 (측정 · 저장 없음)
    func showDemo(state: StudyPresenceState, net: Int, status: Status = .measuring, preview: Bool = false) {
        isDemo = true
        self.state = state
        netSeconds = net
        measuredSeconds = net + 300
        self.status = preview ? .previewing : status
        if preview {
            previewFrame = PresenceFrame(wrists: [PresencePoint(x: 0.66, y: 0.7)], facePoints: [PresencePoint(x: 0.24, y: 0.22)],
                                         bodyPoints: [PresencePoint(x: 0.22, y: 0.36), PresencePoint(x: 0.24, y: 0.72)])
            previewObservation = FrameObservation(present: true, handInArm: true, nearFace: false, motion: 0.2)
        }
        sessionStart = preview ? nil : Date()
    }
    #endif
}

extension StudyPresenceMonitor.Status {
    var isUnavailable: Bool {
        if case .unavailable = self { return true }
        return false
    }
}
