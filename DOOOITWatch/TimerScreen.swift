import SwiftUI
import WatchKit

/// 타이머: 크라운으로 목표 고르기 · 25/50/90분 바로 시작 · 뽀모도로 · 휴식 · 할 일 골라 시작
/// 아이폰에서 켠 타이머도 그대로 보임. 손목을 내리면(항상 켜짐) 시간만 크게
struct TimerScreen: View {
    @Environment(WatchStore.self) private var store
    @Environment(\.isLuminanceReduced) private var dimmed
    /// 고른 목표 (targetChoices 순서, 기본 25분)
    @AppStorage(WatchPrefs.targetKey) private var savedIndex = 5
    @State private var crown: Double = 5
    @State private var showTasks = WatchDemo.screen == "tasks"

    private var choices: [Int?] { WatchTimerState.targetChoices }
    private var index: Int { min(max(Int(crown.rounded()), 0), choices.count - 1) }
    private var accent: Color { store.snapshot.accent }

    var body: some View {
        let timer = store.snapshot.timer
        Group {
            if timer.isActive {
                running(timer)
            } else if let cycle = store.focus, cycle.stage != .focus {
                rest(cycle)
            } else {
                picker
            }
        }
        .navigationTitle(title(timer))
        .onAppear { crown = Double(min(max(savedIndex, 0), choices.count - 1)) }
        .sheet(isPresented: $showTasks) {
            NavigationStack {
                TaskPicker(minutes: choices[index]) { showTasks = false }
            }
        }
    }

    private func title(_ timer: WatchTimerState) -> String {
        if let cycle = store.focus {
            switch cycle.stage {
            case .focus: return timer.isActive ? "집중 \(cycle.round)" : "타이머"
            case .rest, .ready: return cycle.restOnly ? "휴식" : (cycle.isLongRest ? "긴 휴식" : "휴식")
            }
        }
        return "타이머"
    }

    // MARK: 시작 전: 목표 고르기

    private var picker: some View {
        VStack(spacing: 6) {
            ZStack {
                WatchRing(progress: store.snapshot.goalProgress(at: Date()), color: accent.opacity(0.55), lineWidth: 7)
                VStack(spacing: 0) {
                    Text(WatchTimerState.targetLabel(choices[index]))
                        .font(.system(size: choices[index] == nil ? 36 : 26, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("오늘 \(WatchFormat.short(store.snapshot.studySeconds(at: Date())))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
            }
            .frame(maxWidth: 100, maxHeight: 100)
            .focusable()
            .digitalCrownRotation($crown, from: 0, through: Double(choices.count - 1), by: 1,
                                  sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: index) { _, value in savedIndex = value }
            .accessibilityLabel("목표 \(WatchTimerState.targetLabel(choices[index]))")

            HStack(spacing: 4) {
                ForEach([25, 50, 90], id: \.self) { minutes in
                    WatchChip(label: "\(minutes)", color: accent) { store.start(minutes: minutes) }
                        .accessibilityLabel("\(minutes)분 시작")
                }
                WatchChip(label: "뽀모", color: .orange) { store.startPomodoro() }
                    .accessibilityLabel("뽀모도로 \(WatchPrefs.focusMinutes)분 집중")
            }

            Button {
                store.start(minutes: choices[index])
            } label: {
                Label("시작", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .tint(accent)
            .buttonStyle(.borderedProminent)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    store.startRest(minutes: WatchPrefs.restMinutes)
                } label: {
                    Image(systemName: "cup.and.saucer.fill")
                }
                .accessibilityLabel("\(WatchPrefs.restMinutes)분 휴식")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showTasks = true
                } label: {
                    Image(systemName: "checklist")
                }
                .accessibilityLabel("할 일 골라 시작")
            }
        }
    }

    // MARK: 공부 중

    private func running(_ timer: WatchTimerState) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let remaining = timer.remaining(at: now)
            let reached = (remaining ?? 1) <= 0
            let pomodoro = store.focus.map { $0.stage == .focus && $0.owns(timer) } ?? false
            let color: Color = reached ? .green : (pomodoro ? .orange : accent)
            VStack(spacing: 6) {
                ZStack {
                    WatchRing(progress: timer.progress(at: now) ?? store.snapshot.goalProgress(at: now),
                              color: dimmed ? color.opacity(0.5) : color, lineWidth: dimmed ? 6 : 9)
                    VStack(spacing: 0) {
                        Text(reached ? "목표 달성!" : (timer.phase == .paused ? "멈춤" : (remaining == nil ? "공부 중" : "남은 시간")))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(reached ? .green : .secondary)
                        clock(timer, now: now, remaining: remaining, reached: reached)
                            .font(.system(size: dimmed ? 30 : 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .opacity(timer.phase == .paused ? 0.6 : 1)
                        if !dimmed {
                            Text(timer.title == "자유 공부" ? "오늘 \(WatchFormat.short(store.snapshot.studySeconds(at: now)))" : timer.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: dimmed ? 140 : 118, maxHeight: dimmed ? 140 : 118)

                if !dimmed {
                    HStack(spacing: 8) {
                        Button {
                            store.send(timer.phase == .running ? .pauseTimer : .resumeTimer)
                            WatchHaptics.play(.click)
                        } label: {
                            Image(systemName: timer.phase == .running ? "pause.fill" : "play.fill")
                                .font(.title3)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(color)
                        .accessibilityLabel(timer.phase == .running ? "멈춤" : "다시 시작")

                        Button {
                            store.stop()
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

    /// 손목을 내렸을 때도 초가 흐르게 시스템 타이머 글씨 사용
    @ViewBuilder
    private func clock(_ timer: WatchTimerState, now: Date, remaining: TimeInterval?, reached: Bool) -> some View {
        if dimmed, timer.phase == .running, let since = timer.runningSince {
            if let goal = timer.goalDate, goal > now {
                Text(timerInterval: now...goal, countsDown: true)
            } else {
                Text(timerInterval: since...Date.distantFuture, countsDown: false)
            }
        } else {
            Text(WatchFormat.clock(reached || remaining == nil ? timer.elapsed(at: now) : (remaining ?? 0)))
        }
    }

    // MARK: 휴식 (뽀모도로 사이 · 휴식 버튼)

    private func rest(_ cycle: WatchFocusCycle) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let until = cycle.restUntil ?? now
            let total = Double(cycle.restLength * 60)
            let left = max(0, until.timeIntervalSince(now))
            let ready = cycle.stage == .ready
            VStack(spacing: 6) {
                ZStack {
                    WatchRing(progress: ready ? 1 : 1 - left / max(total, 1), color: .mint, lineWidth: dimmed ? 6 : 9)
                    VStack(spacing: 0) {
                        Image(systemName: ready ? "bolt.fill" : "cup.and.saucer.fill")
                            .font(.caption)
                            .foregroundStyle(.mint)
                        if ready {
                            Text("다시 집중")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        } else if dimmed {
                            Text(timerInterval: now...max(now, until), countsDown: true)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        } else {
                            Text(WatchFormat.clock(left))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        if !cycle.restOnly && !dimmed {
                            Text("\(cycle.round)번 집중함")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: 118, maxHeight: 118)

                if !dimmed {
                    HStack(spacing: 8) {
                        if ready && !cycle.restOnly {
                            Button {
                                store.nextFocus()
                            } label: {
                                Label("\(cycle.focusMinutes)분", systemImage: "play.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(.orange)
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button {
                                store.skipRest()
                            } label: {
                                Image(systemName: "forward.end.fill")
                                    .font(.title3)
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(.mint)
                            .buttonStyle(.bordered)
                            .accessibilityLabel("휴식 건너뛰기")
                        }
                        Button {
                            store.stop()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .frame(maxWidth: 44)
                        }
                        .tint(.gray)
                        .buttonStyle(.bordered)
                        .accessibilityLabel("그만")
                    }
                }
            }
        }
    }
}

/// 오늘 할 일 골라서 그 이름으로 공부 시작 (공부 플랜 먼저)
struct TaskPicker: View {
    @Environment(WatchStore.self) private var store
    var minutes: Int?
    var done: () -> Void

    private var plans: [WatchPlanItem] {
        store.snapshot.plans.filter { !$0.isDone && !$0.isSending }
            .sorted { $0.isStudy && !$1.isStudy }
    }

    var body: some View {
        List {
            if plans.isEmpty {
                WatchEmpty(symbol: "checkmark.circle", text: "남은 할 일이 없어요", color: store.snapshot.accent)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(plans) { plan in
                        Button {
                            store.start(minutes: minutes, plan: plan)
                            done()
                        } label: {
                            HStack(spacing: 8) {
                                Capsule().fill(Color(watchHex: plan.colorHex)).frame(width: 3, height: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(plan.title)
                                        .font(.footnote.weight(.semibold))
                                        .lineLimit(2)
                                    Text(plan.time)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "play.fill")
                                    .font(.caption)
                                    .foregroundStyle(store.snapshot.accent)
                            }
                        }
                    }
                } header: {
                    Text(WatchTimerState.targetLabel(minutes))
                }
            }
        }
        .navigationTitle("할 일 고르기")
    }
}
