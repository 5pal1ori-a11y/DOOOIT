import ActivityKit
import SwiftUI
import WidgetKit

@main
struct DOOOITWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StudyLiveActivity()
    }
}

struct StudyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivityAttributes.self) { context in
            StudyLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.78))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.categoryName)
                    } icon: {
                        Image(systemName: context.attributes.symbol)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ActivityTimeText(state: context.state)
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(statusText(for: context.state))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbol)
                    .foregroundStyle(.white)
            } compactTrailing: {
                ActivityTimeText(state: context.state)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: context.state.phase == .upcoming ? "alarm" : "timer")
                    .foregroundStyle(.white)
            }
            .keylineTint(.white)
        }
    }

    private func statusText(for state: StudyActivityAttributes.ContentState) -> String {
        switch state.phase {
        case .upcoming: return "시작까지 남은 시간 · 시간이 되면 타이머가 시작돼요"
        case .studying: return "집중해서 공부하는 중"
        case .paused: return "일시정지됨"
        }
    }
}

struct StudyLockScreenView: View {
    let context: ActivityViewContext<StudyActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.15))
                Image(systemName: context.attributes.symbol)
                    .font(.title3.weight(.semibold))
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(context.attributes.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            ActivityTimeText(state: context.state)
                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 130, alignment: .trailing)
        }
        .foregroundStyle(.white)
        .padding(16)
    }

    private var headline: String {
        switch context.state.phase {
        case .upcoming: return "곧 시작해요 · DOOOIT"
        case .studying: return "공부 중 · DOOOIT"
        case .paused: return "일시정지 · DOOOIT"
        }
    }
}

struct ActivityTimeText: View {
    let state: StudyActivityAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .upcoming:
            let now = Date()
            Text(timerInterval: now...max(state.referenceDate, now), countsDown: true)
        case .studying:
            Text(timerInterval: state.referenceDate...Date.distantFuture, countsDown: false)
        case .paused:
            Text(ActivityTimeFormat.clock(state.pausedElapsed))
        }
    }
}
