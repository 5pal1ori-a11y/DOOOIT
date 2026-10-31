import ActivityKit
import Foundation

/// 다이나믹 아일랜드 / 잠금화면 Live Activity 관리
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var current: Activity<StudyActivityAttributes>? {
        Activity<StudyActivityAttributes>.activities.first
    }

    private var canShow: Bool {
        AppSettings.liveActivityEnabled && ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// 일정 시작 전 "N분 남음" 카운트다운
    func showUpcoming(title: String, category: String, symbol: String, planKey: String, start: Date) {
        guard canShow else { return }
        if let activity = current, activity.attributes.planKey == planKey,
           activity.content.state.phase == .upcoming {
            return
        }
        let state = StudyActivityAttributes.ContentState(phase: .upcoming, referenceDate: start, pausedElapsed: 0)
        let attributes = StudyActivityAttributes(title: title, categoryName: category, symbol: symbol, planKey: planKey)
        replace(with: attributes, state: state, staleDate: start.addingTimeInterval(60))
    }

    /// 공부 타이머 진행 중
    func showStudying(title: String, category: String, symbol: String, planKey: String, referenceDate: Date) {
        guard canShow else { return }
        let state = StudyActivityAttributes.ContentState(phase: .studying, referenceDate: referenceDate, pausedElapsed: 0)
        if let activity = current, activity.attributes.planKey == planKey {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }
        let attributes = StudyActivityAttributes(title: title, categoryName: category, symbol: symbol, planKey: planKey)
        replace(with: attributes, state: state, staleDate: nil)
    }

    func showPaused(elapsed: TimeInterval) {
        guard let activity = current else { return }
        let state = StudyActivityAttributes.ContentState(phase: .paused, referenceDate: Date(), pausedElapsed: elapsed)
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    /// 시작 시간이 지났는데 남아있는 카운트다운 정리
    func endStaleUpcoming(now: Date = Date()) {
        for activity in Activity<StudyActivityAttributes>.activities
        where activity.content.state.phase == .upcoming && activity.content.state.referenceDate < now.addingTimeInterval(-60) {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func endAll() {
        for activity in Activity<StudyActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func replace(with attributes: StudyActivityAttributes,
                         state: StudyActivityAttributes.ContentState,
                         staleDate: Date?) {
        let old = Activity<StudyActivityAttributes>.activities
        Task {
            for activity in old {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            do {
                _ = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: staleDate),
                    pushType: nil
                )
            } catch {
                print("Live Activity 시작 실패: \(error)")
            }
        }
    }
}
