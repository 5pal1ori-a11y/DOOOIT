import SwiftData
import SwiftUI

/// 전체 화면 공부 타이머 (검은 화면 · 큰 숫자 · 아래 두 버튼)
struct TimerView: View {
    @Environment(StudyTimer.self) private var studyTimer
    @Query(sort: \PlanCategory.sortIndex) private var categories: [PlanCategory]
    @Query private var sessions: [StudySession]

    @State private var freeTitle = ""
    @State private var selectedCategoryID: UUID?
    @State private var targetMinutes: Int? = TimerView.savedTarget
    @State private var showTargetPicker = false
    @State private var showStopConfirm = false
    @State private var savedSeconds: Int?
    @State private var sound = AmbientSoundPlayer.shared
    @State private var showSounds = false

    private let targets: [Int?] = [25, 50, 90, nil]
    /// 마지막으로 고른 목표 시간 (0 = 무제한)
    private static let targetKey = "timer.targetMinutes"
    private static var savedTarget: Int? {
        guard let value = UserDefaults.standard.object(forKey: targetKey) as? Int else { return 50 }
        return value > 0 ? value : nil
    }
    private var isCustomTarget: Bool { !targets.contains(targetMinutes) }
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

    /// 가운데 큰 목표 시간 → 목표 칩 → 과목 칩 → 할 일(선택) → 공부 시작
    private var setup: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            // 고른 목표 시간을 크게
            VStack(spacing: 10) {
                Text(selectedCategory.map { "\($0.name) · 목표" } ?? "목표 시간")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(white: 0.55))
                Button { showTargetPicker = true } label: {
                    Text(targetMinutes.map(Self.clockText) ?? "∞")
                        .font(.system(size: 76, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityHint("눌러서 시간 정하기")
            }
            .frame(maxWidth: .infinity)
            .animation(.snappy, value: targetMinutes)

            HStack(spacing: 8) {
                ForEach(targets, id: \.self) { minutes in
                    let isOn = targetMinutes == minutes
                    Button {
                        targetMinutes = minutes
                        Haptics.tap()
                    } label: {
                        Text(minutes.map { "\($0)분" } ?? "무제한")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(isOn ? Color.black : Color.white)
                            .background(isOn ? Color.white : panel, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    showTargetPicker = true
                    Haptics.tap()
                } label: {
                    Text(isCustomTarget ? targetMinutes.map(Self.shortText) ?? "직접" : "직접")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isCustomTarget ? Color.black : Color.white)
                        .background(isCustomTarget ? Color.white : panel, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 28)
            .onChange(of: targetMinutes) { _, minutes in
                UserDefaults.standard.set(minutes ?? 0, forKey: Self.targetKey)
            }
            .sheet(isPresented: $showTargetPicker) {
                TargetTimePicker(minutes: targetMinutes ?? 50) { targetMinutes = $0 }
                    .presentationDetents([.height(340)])
            }

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(studyCategories) { category in
                            let isOn = selectedCategory?.id == category.id
                            Button {
                                selectedCategoryID = category.id
                                Haptics.tap()
                            } label: {
                                Label(category.name, systemImage: category.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .foregroundStyle(isOn ? Color.black : Color.white)
                                    .background(isOn ? Color.white : panel, in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)

                HStack(spacing: 10) {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color(white: 0.5))
                    TextField("할 일 (선택)", text: $freeTitle)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(panel, in: .rect(cornerRadius: 16))

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
                .padding(.top, 4)
            }
        }
    }

    /// 25 → "25:00", 90 → "1:30:00"
    static func clockText(_ minutes: Int) -> String {
        minutes < 60 ? String(format: "%02d:00", minutes) : String(format: "%d:%02d:00", minutes / 60, minutes % 60)
    }

    /// 칩에 쓰는 짧은 글: 40 → "40분", 70 → "1시간 10분"
    static func shortText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)분" }
        return minutes % 60 == 0 ? "\(minutes / 60)시간" : "\(minutes / 60)시간 \(minutes % 60)분"
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
        return "탭해서 시작"
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

/// 목표 시간 직접 정하기 (시간 · 분)
struct TargetTimePicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hours: Int
    @State private var minutes: Int
    let onDone: (Int) -> Void

    init(minutes total: Int, onDone: @escaping (Int) -> Void) {
        _hours = State(initialValue: min(total / 60, 12))
        _minutes = State(initialValue: total % 60)
        self.onDone = onDone
    }

    private var total: Int { hours * 60 + minutes }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("시간", selection: $hours) {
                    ForEach(0...12, id: \.self) { Text("\($0)시간").tag($0) }
                }
                .pickerStyle(.wheel)
                Picker("분", selection: $minutes) {
                    ForEach(0..<60, id: \.self) { Text("\($0)분").tag($0) }
                }
                .pickerStyle(.wheel)
            }
            .padding(.horizontal)
            .navigationTitle("목표 시간")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        onDone(total)
                        Haptics.tap()
                        dismiss()
                    }
                    .disabled(total == 0)
                }
            }
        }
    }
}
