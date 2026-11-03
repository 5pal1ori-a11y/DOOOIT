import SwiftUI
import WatchKit

/// 타이머: 크라운으로 목표(∞ · 5분 단위) 고르고 시작 · 멈춤 · 끝. 아이폰에서 켠 타이머도 그대로 보임
struct TimerScreen: View {
    @Environment(WatchStore.self) private var store
    /// 고른 목표 (targetChoices 순서, 기본 25분)
    @AppStorage("watch.targetIndex") private var savedIndex = 5
    @State private var crown: Double = 5

    private var choices: [Int?] { WatchTimerState.targetChoices }
    private var index: Int { min(max(Int(crown.rounded()), 0), choices.count - 1) }
    private var accent: Color { store.snapshot.accent }

    var body: some View {
        let timer = store.snapshot.timer
        Group {
            if timer.isActive {
                running(timer)
            } else {
                picker
            }
        }
        .navigationTitle("타이머")
        .onAppear { crown = Double(min(max(savedIndex, 0), choices.count - 1)) }
    }

    // MARK: 시작 전: 목표 고르기

    private var picker: some View {
        VStack(spacing: 6) {
            ZStack {
                WatchRing(progress: store.snapshot.goalProgress(at: Date()), color: accent.opacity(0.55), lineWidth: 7)
                VStack(spacing: 0) {
                    Text(WatchTimerState.targetLabel(choices[index]))
                        .font(.system(size: choices[index] == nil ? 40 : 30, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("오늘 \(WatchFormat.duration(store.snapshot.studySeconds(at: Date())))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
            }
            .frame(maxWidth: 118, maxHeight: 118)
            .focusable()
            .digitalCrownRotation($crown, from: 0, through: Double(choices.count - 1), by: 1,
                                  sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: index) { _, value in savedIndex = value }
            .accessibilityLabel("목표 \(WatchTimerState.targetLabel(choices[index]))")

            Button {
                let minutes = choices[index]
                if minutes != nil { store.askNotificationIfNeeded() }
                store.send(.startTimer(targetMinutes: minutes))
                WKInterfaceDevice.current().play(.start)
            } label: {
                Label("시작", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .tint(accent)
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: 공부 중

    private func running(_ timer: WatchTimerState) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let remaining = timer.remaining(at: now)
            let reached = (remaining ?? 1) <= 0
            VStack(spacing: 6) {
                ZStack {
                    WatchRing(progress: timer.progress(at: now) ?? store.snapshot.goalProgress(at: now),
                              color: reached ? .green : accent)
                    VStack(spacing: 0) {
                        Text(reached ? "목표 달성!" : (timer.phase == .paused ? "멈춤" : (remaining == nil ? "공부 중" : "남은 시간")))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(reached ? .green : .secondary)
                        Text(WatchFormat.clock(reached || remaining == nil ? timer.elapsed(at: now) : (remaining ?? 0)))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .opacity(timer.phase == .paused ? 0.6 : 1)
                        Text("오늘 \(WatchFormat.short(store.snapshot.studySeconds(at: now)))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: 118, maxHeight: 118)

                HStack(spacing: 8) {
                    Button {
                        store.send(timer.phase == .running ? .pauseTimer : .resumeTimer)
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: timer.phase == .running ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(accent)
                    .accessibilityLabel(timer.phase == .running ? "멈춤" : "다시 시작")

                    Button {
                        store.send(.stopTimer)
                        WKInterfaceDevice.current().play(.stop)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.red)
                    .accessibilityLabel("끝내고 기록")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
