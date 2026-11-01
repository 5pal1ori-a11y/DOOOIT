import SwiftData
import SwiftUI

/// 전체 화면 공부 타이머
struct TimerView: View {
    @Environment(StudyTimer.self) private var studyTimer
    @Query(sort: \PlanCategory.sortIndex) private var categories: [PlanCategory]

    @State private var freeTitle = ""
    @State private var selectedCategoryID: UUID?
    @State private var targetMinutes: Int? = 50
    @State private var showStopConfirm = false
    @State private var savedSeconds: Int?

    private let targets: [Int?] = [25, 50, 90, nil]

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                topBar
                Spacer()
                Group {
                    if let savedSeconds {
                        summary(seconds: savedSeconds)
                    } else if studyTimer.phase == .idle {
                        setup
                    } else {
                        running
                    }
                }
                .transition(.blurReplace)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .animation(.smooth(duration: 0.4), value: studyTimer.phase)
        .animation(.smooth(duration: 0.4), value: savedSeconds)
        .confirmationDialog("공부를 마칠까요?", isPresented: $showStopConfirm, titleVisibility: .visible) {
            Button(studyTimer.lockUntil != nil ? "종료하고 잠금 해제" : "종료하고 기록 저장", role: .destructive) {
                savedSeconds = studyTimer.stop()
            }
            Button("계속하기", role: .cancel) {}
        } message: {
            if studyTimer.lockUntil != nil {
                Text("지금 끝내면 다른 앱 잠금도 바로 해제돼요.")
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                studyTimer.isPresented = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)

            Spacer()

            Text(studyTimer.phase == .idle ? "공부 타이머" : studyTimer.categoryName)
                .font(.headline)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 8)
    }

    // MARK: Setup (idle)

    private var studyCategories: [PlanCategory] {
        let study = categories.filter(\.isStudy)
        return study.isEmpty ? categories : study
    }

    private var selectedCategory: PlanCategory? {
        studyCategories.first { $0.id == selectedCategoryID } ?? studyCategories.first
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("무엇을 공부할까요?")
                    .font(.largeTitle.weight(.bold))
                Text("타이머를 시작하면 다이나믹 아일랜드에 공부 시간이 표시돼요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("예: 수학 문제집 3단원", text: $freeTitle)
                .font(.title3)
                .glassField()

            VStack(alignment: .leading, spacing: 10) {
                Text("카테고리").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(studyCategories) { category in
                            let isOn = selectedCategory?.id == category.id
                            Button {
                                selectedCategoryID = category.id
                            } label: {
                                Label(category.name, systemImage: category.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(isOn ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(isOn ? .regular.tint(category.color).interactive() : .regular.interactive(), in: .capsule)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("목표 시간").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(targets, id: \.self) { minutes in
                        let isOn = targetMinutes == minutes
                        Button {
                            targetMinutes = minutes
                        } label: {
                            Text(minutes.map { "\($0)분" } ?? "무제한")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(isOn ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(isOn ? .regular.tint(Theme.accent).interactive() : .regular.interactive(), in: .capsule)
                    }
                }
            }

            Button {
                let category = selectedCategory
                studyTimer.start(
                    title: freeTitle.trimmingCharacters(in: .whitespaces),
                    categoryName: category?.name ?? "공부",
                    symbol: category?.symbol ?? "book.fill",
                    targetMinutes: targetMinutes
                )
                Haptics.success()
            } label: {
                Label("공부 시작", systemImage: "play.fill")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.top, 6)
        }
    }

    // MARK: Running

    private var running: some View {
        VStack(spacing: 36) {
            VStack(spacing: 6) {
                if let lockUntil = studyTimer.lockUntil {
                    Label("다른 앱 잠금 중 · \(lockUntil.kr("a h:mm"))까지", systemImage: "lock.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.danger)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Palette.danger.opacity(0.14), in: .capsule)
                        .padding(.bottom, 8)
                }
                Image(systemName: studyTimer.symbol)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                Text(studyTimer.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = studyTimer.elapsed(at: context.date)
                let target = studyTimer.targetSeconds
                let progress = target.map { elapsed / Double(max($0, 1)) } ?? (elapsed.truncatingRemainder(dividingBy: 3600) / 3600)

                ZStack {
                    ProgressRing(progress: progress, lineWidth: 14,
                                 color: (target != nil && elapsed >= Double(target ?? 0)) ? Palette.success : Theme.accent)

                    VStack(spacing: 8) {
                        Text(TimeText.clock(elapsed))
                            .font(.system(size: 50, weight: .bold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if let target {
                            if elapsed >= Double(target) {
                                Label("목표 달성!", systemImage: "checkmark.seal.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Palette.success)
                            } else {
                                Text("목표 \(TimeText.duration(seconds: target)) · \(TimeText.duration(seconds: target - Int(elapsed) + 59)) 남음")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(studyTimer.phase == .paused ? "일시정지됨" : "집중하는 중")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .frame(width: 290, height: 290)
                .padding(18)
                .glassEffect(.regular, in: .circle)
            }

            GlassEffectContainer(spacing: 24) {
                HStack(spacing: 28) {
                    Button { showStopConfirm = true } label: {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundStyle(Palette.danger)
                            .frame(width: 70, height: 70)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)

                    Button {
                        studyTimer.togglePause()
                        Haptics.tap()
                    } label: {
                        Image(systemName: studyTimer.phase == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 92, height: 92)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(Theme.accent).interactive(), in: .circle)
                }
            }
        }
    }

    // MARK: Summary

    private func summary(seconds: Int) -> some View {
        VStack(spacing: 22) {
            Image(systemName: seconds >= 10 ? "checkmark.seal.fill" : "clock.badge.xmark")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(seconds >= 10 ? Palette.success : Color.secondary)
                .symbolEffect(.bounce, value: seconds)
            VStack(spacing: 6) {
                Text(seconds >= 10 ? "수고했어요!" : "기록이 너무 짧아요")
                    .font(.title.weight(.bold))
                Text(seconds >= 10 ? "\(TimeText.clock(TimeInterval(seconds))) 공부를 기록했어요." : "10초 이상 공부해야 기록돼요.")
                    .foregroundStyle(.secondary)
            }
            Button {
                savedSeconds = nil
                studyTimer.isPresented = false
            } label: {
                Text("닫기")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }
}

/// 탭바 위 미니 플레이어 (iOS 26 tabViewBottomAccessory)
struct TimerAccessoryView: View {
    @Environment(StudyTimer.self) private var studyTimer
    @Query(sort: \Plan.startDate) private var plans: [Plan]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: studyTimer.isActive ? studyTimer.symbol : "timer")
                .font(.headline)
                .foregroundStyle(Theme.accent)
                .symbolEffect(.pulse, isActive: studyTimer.phase == .running)

            VStack(alignment: .leading, spacing: 1) {
                if studyTimer.isActive {
                    Text(studyTimer.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(TimeText.clock(studyTimer.elapsed(at: context.date)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("바로 공부 시작")
                        .font(.subheadline.weight(.semibold))
                    Text(nextPlanText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if studyTimer.isActive {
                Button {
                    studyTimer.togglePause()
                } label: {
                    Image(systemName: studyTimer.phase == .running ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "play.fill")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { studyTimer.isPresented = true }
    }

    private var nextPlanText: String {
        let now = Date()
        if let next = plans.occurrences(on: now).first(where: { $0.plan.isStudy && !$0.plan.isAllDay && $0.start > now }) {
            return "다음: \(next.plan.title) \(next.start.kr("a h:mm"))"
        }
        return "타이머를 눌러 집중 시간을 기록하세요"
    }
}
