import Foundation
import SwiftData

/// 플래너의 "공부" 카테고리 일정을 감시하여
/// - 시작 N분 전: 다이나믹 아일랜드 카운트다운
/// - 시작 시각: 공부 타이머 자동 실행
@MainActor
final class PlanScheduler {
    static let shared = PlanScheduler()

    private var context: ModelContext?
    private weak var timer: StudyTimer?
    private var ticker: Timer?
    private let handledKey = "dooit.autoStartedPlanKeys"

    func start(context: ModelContext, timer: StudyTimer) {
        self.context = context
        self.timer = timer
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            Task { @MainActor in PlanScheduler.shared.tick() }
        }
        tick()
        rescheduleNotifications()
    }

    func rescheduleNotifications() {
        guard let context else { return }
        let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        NotificationService.reschedule(plans: plans)
    }

    func tick() {
        guard let context, let timer else { return }
        let now = Date()
        let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        let today = plans.occurrences(on: now).filter { $0.plan.isStudy && !$0.plan.isAllDay }

        // 1) 시작 시각이 된 공부 일정 → 타이머 자동 시작
        if AppSettings.autoStartTimer,
           let current = today.first(where: { now >= $0.start && now < $0.end && !handled.contains($0.id) }) {
            markHandled(current.id)
            if timer.phase == .idle {
                startTimer(for: current, now: now)
            }
            return
        }

        // 2) 시작 N분 전 → 다이나믹 아일랜드 카운트다운
        guard timer.phase == .idle else { return }
        let lead = TimeInterval(AppSettings.leadMinutes * 60)
        let next = today
            .filter { $0.start > now && $0.start.timeIntervalSince(now) <= lead }
            .min { $0.start < $1.start }

        if let next {
            LiveActivityManager.shared.showUpcoming(
                title: next.plan.title,
                category: next.plan.category?.name ?? "공부",
                symbol: next.plan.symbol,
                planKey: next.id,
                start: next.start
            )
        } else {
            LiveActivityManager.shared.endStaleUpcoming(now: now)
        }
    }

    /// 알림을 눌러 들어온 경우
    func startFromNotification(planID: UUID) {
        guard let context, let timer else { return }
        let plans = (try? context.fetch(FetchDescriptor<Plan>())) ?? []
        guard let plan = plans.first(where: { $0.id == planID }) else { return }
        let now = Date()
        guard let occurrence = [plan].occurrences(on: now).first else { return }
        markHandled(occurrence.id)
        if timer.phase == .idle {
            startTimer(for: occurrence, now: now)
        } else {
            timer.isPresented = true
        }
    }

    private func startTimer(for occurrence: PlanOccurrence, now: Date) {
        guard let timer else { return }
        let remaining = max(1, Int(occurrence.end.timeIntervalSince(now) / 60))
        timer.start(
            title: occurrence.plan.title,
            categoryName: occurrence.plan.category?.name ?? "공부",
            symbol: occurrence.plan.symbol,
            planKey: occurrence.id,
            targetMinutes: min(occurrence.plan.durationMinutes, remaining)
        )
        timer.isPresented = true
    }

    // MARK: 같은 일정이 여러 번 자동 시작되지 않도록 기록

    private var handled: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: handledKey) ?? [])
    }

    private func markHandled(_ key: String) {
        let todayKey = Date().dayKey
        var keys = handled.filter { $0.hasSuffix(todayKey) }
        keys.insert(key)
        UserDefaults.standard.set(Array(keys), forKey: handledKey)
    }
}
