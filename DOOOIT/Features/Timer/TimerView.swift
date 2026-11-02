import SwiftData
import SwiftUI

/// 전체 화면 공부 타이머 (검은 화면 · 큰 숫자 · 아래 두 버튼)
struct TimerView: View {
    @Environment(StudyTimer.self) private var studyTimer
    @Query(sort: \PlanCategory.sortIndex) private var categories: [PlanCategory]
    @Query private var sessions: [StudySession]

    @State private var freeTitle = ""
    @State private var selectedCategoryID: UUID?
    @State private var targetMinutes: Int? = 50
    @State private var showStopConfirm = false
    @State private var savedSeconds: Int?
    @State private var sound = AmbientSoundPlayer.shared
    @State private var showSounds = false

    private let targets: [Int?] = [25, 50, 90, nil]
    /// 어두운 화면의 버튼 바탕
    private let panel = Color(white: 0.11)
    private let line = Color(white: 0.22)
    private let green = Color(hex: "#34C759")

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Group {
                    if let savedSeconds {
                        summary(seconds: savedSeconds)
                    } else if studyTimer.phase == .idle {
                        setup
                    } else {
                        running
                    }
                }
                .transition(.opacity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .animation(.smooth(duration: 0.35), value: studyTimer.phase)
        .animation(.smooth(duration: 0.35), value: savedSeconds)
        .confirmationDialog("공부를 마칠까요?", isPresented: $showStopConfirm, titleVisibility: .visible) {
            Button(studyTimer.lockUntil != nil ? "완료하고 잠금 해제" : "완료하고 기록 저장", role: .destructive) {
                savedSeconds = studyTimer.stop()
                submitRanking()
            }
            Button("계속하기", role: .cancel) {}
        } message: {
            if studyTimer.lockUntil != nil {
                Text("지금 끝내면 다른 앱 잠금도 바로 해제돼요.")
            }
        }
    }

    /// 공부를 마치면 랭킹에도 반영 (랭킹에 참여한 경우만)
    private func submitRanking() {
        Task {
            try? await Task.sleep(for: .seconds(1))
            await RankingService.shared.submit { start, end in
                sessions.filter { $0.start >= start && $0.start < end }.reduce(0) { $0 + $1.seconds }
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        ZStack {
            Text("타이머").font(.headline)
            HStack {
                Button {
                    studyTimer.isPresented = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("닫기")
                Spacer()
                Button {
                    showSounds = true
                } label: {
                    Image(systemName: sound.current?.symbol ?? "speaker.wave.2")
                        .font(.headline)
                        .foregroundStyle(sound.isPlaying ? green : .white)
                        .symbolEffect(.variableColor.iterative, isActive: sound.isPlaying)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("집중 사운드")
            }
        }
        .padding(.top, 4)
        .sheet(isPresented: $showSounds) {
            AmbientSoundSheet()
                .presentationDetents([.medium])
        }
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
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 6) {
                Text("무엇을 공부할까요?").font(.title.weight(.bold))
                Text("시작하면 다이나믹 아일랜드에 공부 시간이 표시돼요.").font(.subheadline).foregroundStyle(Color(white: 0.6))
            }

            TextField("예: 수학 문제집 3단원", text: $freeTitle)
                .font(.title3)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(panel, in: .rect(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 10) {
                Text("카테고리").font(.subheadline.weight(.semibold)).foregroundStyle(Color(white: 0.6))
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
                                    .foregroundStyle(isOn ? Color.black : Color.white)
                                    .background(isOn ? Color.white : panel, in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("목표 시간").font(.subheadline.weight(.semibold)).foregroundStyle(Color(white: 0.6))
                HStack(spacing: 8) {
                    ForEach(targets, id: \.self) { minutes in
                        let isOn = targetMinutes == minutes
                        Button {
                            targetMinutes = minutes
                        } label: {
                            Text(minutes.map { "\($0)분" } ?? "무제한")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .foregroundStyle(isOn ? Color.black : Color.white)
                                .background(isOn ? Color.white : panel, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

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
                    .font(.body.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(green, in: .capsule)
            }
            .buttonStyle(.pressable)
        }
    }

    // MARK: Running (가운데 제목 · 선 · 큰 숫자 · 선 / 아래 두 버튼)

    private var running: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 22) {
                if let lockUntil = studyTimer.lockUntil {
                    Label("다른 앱 잠금 중 · \(lockUntil.kr("a h:mm"))까지", systemImage: "lock.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.danger)
                }
                Text(studyTimer.title)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = studyTimer.elapsed(at: context.date)
                    VStack(spacing: 14) {
                        Rectangle().fill(line).frame(height: 1)
                        Text(TimeText.clock(elapsed))
                            .font(.system(size: 72, weight: .bold).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                            .opacity(studyTimer.phase == .paused ? 0.45 : 1)
                        Rectangle().fill(line).frame(height: 1)
                        statusText(elapsed: elapsed)
                    }
                    .padding(.horizontal, 12)
                }
            }
            Spacer()
            HStack(spacing: 12) {
                pillButton(title: studyTimer.phase == .running ? "진행 중" : "일시정지",
                           symbol: studyTimer.phase == .running ? "pause.fill" : "play.fill",
                           iconColor: green) {
                    studyTimer.togglePause()
                    Haptics.tap()
                }
                pillButton(title: "완료하기", symbol: "stop.fill", iconColor: .white) {
                    showStopConfirm = true
                }
            }
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func statusText(elapsed: TimeInterval) -> some View {
        if let target = studyTimer.targetSeconds {
            if elapsed >= Double(target) {
                Label("목표 달성!", systemImage: "checkmark.seal.fill").font(.subheadline.weight(.semibold)).foregroundStyle(green)
            } else {
                Text("목표 \(TimeText.duration(seconds: target)) · \(TimeText.duration(seconds: target - Int(elapsed) + 59)) 남음")
                    .font(.subheadline).foregroundStyle(Color(white: 0.55))
            }
        } else {
            Text(studyTimer.phase == .paused ? "일시정지됨" : studyTimer.categoryName)
                .font(.subheadline).foregroundStyle(Color(white: 0.55))
        }
    }

    /// 아래쪽 둥근 버튼: 왼쪽 동그란 아이콘 + 글자
    private func pillButton(title: String, symbol: String, iconColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(iconColor)
                    .frame(width: 46, height: 46)
                    .background(Color.black, in: .circle)
                    .contentTransition(.symbolEffect(.replace))
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.leading, 8)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(panel, in: .capsule)
        }
        .buttonStyle(.pressable)
    }

    // MARK: Summary

    private func summary(seconds: Int) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: seconds >= 10 ? "checkmark.seal.fill" : "clock.badge.xmark")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(seconds >= 10 ? green : Color(white: 0.5))
                .symbolEffect(.bounce, value: seconds)
            VStack(spacing: 8) {
                Text(seconds >= 10 ? "수고했어요!" : "기록이 너무 짧아요")
                    .font(.title.weight(.bold))
                Text(seconds >= 10 ? TimeText.clock(TimeInterval(seconds)) : "10초 이상 공부해야 기록돼요.")
                    .font(seconds >= 10 ? .system(size: 44, weight: .bold).monospacedDigit() : .body)
                    .foregroundStyle(seconds >= 10 ? Color.white : Color(white: 0.6))
                if seconds >= 10, RankingService.shared.isJoined {
                    Text("랭킹에도 반영했어요").font(.subheadline).foregroundStyle(Color(white: 0.6))
                }
            }
            Spacer()
            Button {
                savedSeconds = nil
                studyTimer.isPresented = false
            } label: {
                Text("닫기")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white, in: .capsule)
            }
            .buttonStyle(.pressable)
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

/// 집중 사운드 고르기 + 음량
struct AmbientSoundSheet: View {
    @State private var sound = AmbientSoundPlayer.shared

    var body: some View {
        @Bindable var sound = sound
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(AmbientSoundPlayer.Kind.allCases) { kind in
                            let isOn = sound.current == kind
                            Button {
                                sound.toggle(kind)
                                Haptics.tap()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Image(systemName: kind.symbol)
                                        .font(.title3)
                                        .symbolEffect(.variableColor.iterative, isActive: isOn)
                                    Text(kind.title).font(.subheadline.weight(.bold))
                                    Text(kind.subtitle).font(.caption2).opacity(0.75).lineLimit(1)
                                }
                                .foregroundStyle(isOn ? Color.white : Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(isOn ? Theme.accent : Color.primary.opacity(0.05), in: .rect(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $sound.volume, in: 0...1)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    Text("다시 누르면 꺼져요. 공부를 마치면 자동으로 꺼지고, 화면을 꺼도 계속 들려요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("집중 사운드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if sound.isPlaying {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("끄기") { sound.stop() }
                    }
                }
            }
        }
    }
}
