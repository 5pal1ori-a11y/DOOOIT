import Foundation
import Observation
import SwiftData

/// 공부 타이머. 앱을 종료해도 이어서 계산되도록 상태를 저장합니다.
@MainActor
@Observable
final class StudyTimer {
    static let shared = StudyTimer()

    enum Phase: String, Codable {
        case idle, running, paused
    }

    private(set) var phase: Phase = .idle
    private(set) var title: String = "자유 공부"
    private(set) var categoryName: String = "공부"
    private(set) var symbol: String = "book.fill"
    private(set) var planKey: String?
    private(set) var targetSeconds: Int?
    private(set) var startedAt: Date?
    /// 공부 플랜의 앱 잠금 종료 시각 (잠금이 없으면 nil)
    private(set) var lockUntil: Date?
    private var segmentStart: Date?
    private var accumulated: TimeInterval = 0

    /// 전체 화면 타이머 표시 여부
    var isPresented = false

    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private let storageKey = "dooit.studyTimer"
    @ObservationIgnored private var activityKey = "free"
    private static let maxSessionSeconds = 12 * 60 * 60

    private struct Snapshot: Codable {
        var phase: Phase
        var title: String
        var categoryName: String
        var symbol: String
        var planKey: String?
        var targetSeconds: Int?
        var startedAt: Date?
        var segmentStart: Date?
        var accumulated: TimeInterval
        var lockUntil: Date?
    }

    init() {
        restore()
    }

    func attach(context: ModelContext) {
        self.context = context
    }

    var isActive: Bool { phase != .idle }

    func elapsed(at date: Date = Date()) -> TimeInterval {
        accumulated + (segmentStart.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    /// at: 시작을 누른 시각 (애플 워치에서 늦게 도착한 명령도 기록이 맞게, 보통은 지금)
    func start(title: String, categoryName: String, symbol: String, planKey: String? = nil, targetMinutes: Int? = nil, lockUntil: Date? = nil, at now: Date = Date()) {
        if phase != .idle { stop() }
        self.title = title.isEmpty ? "자유 공부" : title
        self.categoryName = categoryName
        self.symbol = symbol
        self.planKey = planKey
        self.targetSeconds = targetMinutes.map { $0 * 60 }
        self.startedAt = now
        self.segmentStart = now
        self.accumulated = 0
        self.lockUntil = lockUntil
        self.phase = .running
        persist()
        if let lockUntil {
            Task { await AppLockManager.shared.lock(until: lockUntil) }
        }

        activityKey = planKey ?? "free-\(Int(now.timeIntervalSince1970))"
        LiveActivityManager.shared.showStudying(
            title: self.title, category: categoryName, symbol: symbol,
            planKey: activityKey, referenceDate: now
        )
        SocialCenter.shared.timerChanged()
    }

    func pause(at now: Date = Date()) {
        guard phase == .running, let segmentStart else { return }
        accumulated += max(0, now.timeIntervalSince(segmentStart))
        self.segmentStart = nil
        phase = .paused
        persist()
        LiveActivityManager.shared.showPaused(elapsed: accumulated)
        SocialCenter.shared.timerChanged()
    }

    func resume(at now: Date = Date()) {
        guard phase == .paused else { return }
        segmentStart = now
        phase = .running
        persist()
        LiveActivityManager.shared.showStudying(
            title: title, category: categoryName, symbol: symbol,
            planKey: activityKey, referenceDate: now.addingTimeInterval(-accumulated)
        )
        SocialCenter.shared.timerChanged()
    }

    func togglePause() {
        phase == .running ? pause() : resume()
    }

    /// 타이머 종료 후 기록 저장. 저장된 초를 반환.
    @discardableResult
    func stop(at now: Date = Date()) -> Int {
        // 끄는 걸 잊고 며칠 동안 켜 둔 경우 등 비정상적으로 긴 기록은 12시간까지만 저장
        let seconds = min(Int(elapsed(at: now)), Self.maxSessionSeconds)
        if seconds >= 10, let context, let startedAt {
            context.insert(StudySession(title: title, categoryName: categoryName, start: startedAt,
                                        seconds: seconds, planKey: planKey))
            try? context.save()
        }
        if lockUntil != nil {
            AppLockManager.shared.endLock(planKey: planKey)
        }
        lockUntil = nil
        phase = .idle
        title = "자유 공부"
        planKey = nil
        targetSeconds = nil
        startedAt = nil
        segmentStart = nil
        accumulated = 0
        persist()
        LiveActivityManager.shared.endAll()
        SocialCenter.shared.timerChanged()
        return seconds
    }

    private func persist() {
        let snapshot = Snapshot(phase: phase, title: title, categoryName: categoryName, symbol: symbol,
                                planKey: planKey, targetSeconds: targetSeconds, startedAt: startedAt,
                                segmentStart: segmentStart, accumulated: accumulated, lockUntil: lockUntil)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let s = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        phase = s.phase
        title = s.title
        categoryName = s.categoryName
        symbol = s.symbol
        planKey = s.planKey
        targetSeconds = s.targetSeconds
        startedAt = s.startedAt
        segmentStart = s.segmentStart
        accumulated = s.accumulated
        lockUntil = s.lockUntil
        // 앱을 다시 켰을 때도 같은 Live Activity를 이어서 쓰도록
        if phase != .idle {
            activityKey = planKey ?? "free-\(Int((startedAt ?? Date()).timeIntervalSince1970))"
        }
    }
}

#if DEBUG
extension StudyTimer {
    /// 화면 사진용: 진행 중인 모습만 보여 줌 (실제 앱 잠금 · 라이브 액티비티 · 상태 저장 없음)
    func showDemo(title: String, categoryName: String, symbol: String, targetMinutes: Int?, startedAt: Date, lockUntil: Date?) {
        self.title = title
        self.categoryName = categoryName
        self.symbol = symbol
        self.planKey = nil
        self.targetSeconds = targetMinutes.map { $0 * 60 }
        self.startedAt = startedAt
        self.segmentStart = startedAt
        self.accumulated = 0
        self.lockUntil = lockUntil
        self.phase = .running
    }
}
#endif
