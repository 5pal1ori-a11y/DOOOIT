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
    private var segmentStart: Date?
    private var accumulated: TimeInterval = 0

    /// 전체 화면 타이머 표시 여부
    var isPresented = false

    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private let storageKey = "dooit.studyTimer"
    @ObservationIgnored private var activityKey = "free"

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

    func start(title: String, categoryName: String, symbol: String, planKey: String? = nil, targetMinutes: Int? = nil) {
        if phase != .idle { stop() }
        let now = Date()
        self.title = title.isEmpty ? "자유 공부" : title
        self.categoryName = categoryName
        self.symbol = symbol
        self.planKey = planKey
        self.targetSeconds = targetMinutes.map { $0 * 60 }
        self.startedAt = now
        self.segmentStart = now
        self.accumulated = 0
        self.phase = .running
        persist()

        activityKey = planKey ?? "free-\(Int(now.timeIntervalSince1970))"
        LiveActivityManager.shared.showStudying(
            title: self.title, category: categoryName, symbol: symbol,
            planKey: activityKey, referenceDate: now
        )
    }

    func pause() {
        guard phase == .running, let segmentStart else { return }
        accumulated += Date().timeIntervalSince(segmentStart)
        self.segmentStart = nil
        phase = .paused
        persist()
        LiveActivityManager.shared.showPaused(elapsed: accumulated)
    }

    func resume() {
        guard phase == .paused else { return }
        let now = Date()
        segmentStart = now
        phase = .running
        persist()
        LiveActivityManager.shared.showStudying(
            title: title, category: categoryName, symbol: symbol,
            planKey: activityKey, referenceDate: now.addingTimeInterval(-accumulated)
        )
    }

    func togglePause() {
        phase == .running ? pause() : resume()
    }

    /// 타이머 종료 후 기록 저장. 저장된 초를 반환.
    @discardableResult
    func stop() -> Int {
        let seconds = Int(elapsed())
        if seconds >= 10, let context, let startedAt {
            context.insert(StudySession(title: title, categoryName: categoryName, start: startedAt,
                                        seconds: seconds, planKey: planKey))
            try? context.save()
        }
        phase = .idle
        title = "자유 공부"
        planKey = nil
        targetSeconds = nil
        startedAt = nil
        segmentStart = nil
        accumulated = 0
        persist()
        LiveActivityManager.shared.endAll()
        return seconds
    }

    private func persist() {
        let snapshot = Snapshot(phase: phase, title: title, categoryName: categoryName, symbol: symbol,
                                planKey: planKey, targetSeconds: targetSeconds, startedAt: startedAt,
                                segmentStart: segmentStart, accumulated: accumulated)
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
    }
}
