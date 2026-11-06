import SwiftData
import SwiftUI

/// 전체 화면 공부 타이머 (검은 화면 · 큰 숫자 · 아래 두 버튼)
struct TimerView: View {
    @Environment(StudyTimer.self) private var studyTimer
    @Query private var sessions: [StudySession]

    @State private var freeTitle = ""
    /// 고른 오늘 할 일 (없어도 됨)
    @State private var selectedTaskID: String?
    @Query(sort: \Plan.startDate) private var plans: [Plan]
    @State private var targetMinutes: Int? = TimerView.savedTarget
    @State private var showStopConfirm = false
    /// 공부하는 동안 다른 앱 잠그기 (스크린 타임 권한)
    @AppStorage("timer.lockApps") private var lockApps = false
    @State private var lockDenied = false
    @State private var savedSeconds: Int? = {
        #if DEBUG
        return UIShot.matches(.camResult) ? 3600 : nil
        #else
        return nil
        #endif
    }()
    /// AI 순공부 측정 (카메라로 공부 중인지 보고 순공부 시간만 셈, 기본은 꺼짐)
    @AppStorage(StudyPresenceMonitor.enabledKey) private var aiMeasure = false
    @State private var presence = StudyPresenceMonitor.shared
    @State private var presenceSummary: PresenceSummary? = {
        #if DEBUG
        if UIShot.matches(.camResult) {
            return PresenceSummary(startedAt: Date(), totals: PresenceTotals(measured: 3600, net: 3120, away: 300, still: 120, distracted: 60))
        }
        #endif
        return nil
    }()
    @State private var showPresenceGuide: Bool = {
        #if DEBUG
        return UIShot.matches(.camGuide)
        #else
        return false
        #endif
    }()
    @State private var sound = AmbientSoundPlayer.shared
    @State private var showSounds: Bool = {
        #if DEBUG
        return UIShot.matches(.soundMixer)
        #else
        return false
        #endif
    }()

    /// 마지막으로 고른 목표 시간 (0 = 무제한)
    private static let targetKey = "timer.targetMinutes"
    private static var savedTarget: Int? {
        guard let value = UserDefaults.standard.object(forKey: targetKey) as? Int else { return 50 }
        guard value > 0 else { return nil }
        // 스크롤 칸에 있는 값으로 (예전에 직접 고른 값이 칸 사이면 가까운 칸으로)
        return targetOptions.filter { $0 > 0 }.min(by: { abs($0 - value) < abs($1 - value) })
    }
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
        .statusBarHidden()
        .animation(.smooth(duration: 0.35), value: studyTimer.phase)
        .animation(.smooth(duration: 0.35), value: savedSeconds)
        .sheet(isPresented: $showPresenceGuide) {
            PresenceGuideSheet()
                .presentationDetents([.large])
                .presentationBackground(.black)
        }
        // 앱을 껐다 켰는데 공부가 이어지고 있으면 측정도 이어서
        .task { presence.resumeIfNeeded() }
        .confirmationDialog("공부를 마칠까요?", isPresented: $showStopConfirm, titleVisibility: .visible) {
            Button(studyTimer.lockUntil != nil ? L("완료하고 잠금 해제") : L("완료하고 기록 저장"), role: .destructive) {
                let start = studyTimer.startedAt
                let saved = studyTimer.stop()
                presenceSummary = presence.finish(totalSeconds: saved) ?? start.flatMap { PresenceStore().summary(forStart: $0) }
                savedSeconds = saved
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
            Text("타이머").font(.pt(.headline))
            HStack {
                Button {
                    studyTimer.isPresented = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.pt(.title3).weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("닫기")
                Spacer()
                Button {
                    showSounds = true
                } label: {
                    Image(systemName: sound.leadKind?.symbol ?? "speaker.wave.2")
                        .font(.pt(.headline))
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
                .presentationDetents([.medium, .large])
                .presentationBackground(Palette.card)
        }
    }

    // MARK: Setup (idle)

    /// 스크롤해서 고르는 목표 시간 (0 = 무제한): 5분 단위, 3시간까지는 촘촘히, 그 뒤는 30분 단위
    static let targetOptions: [Int] = [0] + Array(stride(from: 5, through: 180, by: 5)) + [210, 240, 300]

    /// 오늘 아직 안 끝낸 할 일 (골라도 되고 안 골라도 됨)
    private var todayTasks: [PlanOccurrence] {
        plans.occurrences(on: Date()).filter { !$0.isCompleted }
    }

    /// 가운데 큰 목표 시간(위아래로 스크롤) → 할 일(선택) → 공부 시작
    private var setup: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            VStack(spacing: 6) {
                Text("목표 시간")
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(Color(white: 0.55))
                targetWheel
            }
            .frame(maxWidth: .infinity)
            .onChange(of: targetMinutes) { _, minutes in
                UserDefaults.standard.set(minutes ?? 0, forKey: Self.targetKey)
            }

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                if !todayTasks.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(todayTasks.prefix(8)) { task in
                                let isOn = selectedTaskID == task.id
                                Button {
                                    if isOn { selectedTaskID = nil; freeTitle = "" }
                                    else { selectedTaskID = task.id; freeTitle = task.plan.title }
                                    Haptics.tap()
                                } label: {
                                    Text(task.plan.title)
                                        .font(.pt(.subheadline).weight(.semibold))
                                        .lineLimit(1)
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
                }

                HStack(spacing: 10) {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color(white: 0.5))
                    TextField("할 일 (선택)", text: $freeTitle)
                        .onChange(of: freeTitle) { _, title in
                            if let id = selectedTaskID, todayTasks.first(where: { $0.id == id })?.plan.title != title { selectedTaskID = nil }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(panel, in: .rect(cornerRadius: 14))

                lockToggle
                presenceToggle

                Button {
                    let task = todayTasks.first { $0.id == selectedTaskID }
                    // 잠금: 목표 시간까지 (무제한이면 끝낼 때까지, 최대 12시간)
                    let lockUntil = lockApps && AppLockManager.shared.isAuthorized
                        ? Date().addingTimeInterval(Double((targetMinutes ?? 12 * 60) * 60)) : nil
                    studyTimer.start(
                        title: freeTitle.trimmingCharacters(in: .whitespaces),
                        categoryName: task?.plan.category?.name ?? "공부",
                        symbol: task?.plan.symbol ?? "book.fill",
                        targetMinutes: targetMinutes,
                        lockUntil: lockUntil
                    )
                    presenceSummary = nil
                    if aiMeasure { presence.begin(startedAt: studyTimer.startedAt ?? Date()) }
                    Haptics.success()
                } label: {
                    Label("공부 시작", systemImage: "play.fill")
                        .font(.pt(.body).weight(.bold))
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

    /// 다른 앱 잠그기 스위치 (처음 켤 때 스크린 타임 권한을 물어봄)
    private var lockToggle: some View {
        Toggle(isOn: Binding(get: { lockApps }, set: { on in
            guard on else { lockApps = false; return }
            Task {
                let ok = await AppLockManager.shared.requestAuthorization()
                lockApps = ok
                if !ok { lockDenied = true }
            }
        })) {
            Label("다른 앱 잠그기", systemImage: "lock.fill")
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(.white)
        }
        .tint(green)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(panel, in: .rect(cornerRadius: 14))
        .alert("스크린 타임 권한이 필요해요", isPresented: $lockDenied) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("권한을 허용해야 공부하는 동안 다른 앱을 잠글 수 있어요.")
        }
    }

    /// AI 순공부 측정 스위치 (켜면 카메라 위치를 맞추는 안내가 나옴)
    private var presenceToggle: some View {
        HStack(spacing: 10) {
            Label("AI 순공부 측정", systemImage: "viewfinder")
                .font(.pt(.subheadline).weight(.semibold))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            if aiMeasure {
                Button("가이드") { showPresenceGuide = true }
                    .font(.pt(.footnote).weight(.semibold))
                    .foregroundStyle(green)
            }
            Toggle("AI 순공부 측정", isOn: Binding(get: { aiMeasure }, set: { on in
                aiMeasure = on
                if on { showPresenceGuide = true }
            }))
            .labelsHidden()
            .tint(green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(panel, in: .rect(cornerRadius: 14))
    }

    /// 큰 숫자를 위아래로 스크롤해서 목표 시간 고르기 (가운데가 고른 시간, 위아래는 흐리게)
    private var targetWheel: some View {
        let rowHeight: CGFloat = 84
        return ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Self.targetOptions, id: \.self) { minutes in
                    Text(minutes == 0 ? "∞" : Self.clockText(minutes))
                        .font(.pt(size: 72, weight: .light))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                        .scrollTransition(axis: .vertical) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.22)
                                .scaleEffect(phase.isIdentity ? 1 : 0.62)
                        }
                        .id(minutes)
                        .accessibilityLabel(minutes == 0 ? L("무제한") : Self.shortText(minutes))
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: Binding(get: { targetMinutes ?? 0 }, set: { targetMinutes = ($0 ?? 0) == 0 ? nil : $0 }), anchor: .center)
        .contentMargins(.vertical, rowHeight, for: .scrollContent)
        .frame(height: rowHeight * 3)
        .mask(LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .top, endPoint: .bottom))
        .sensoryFeedback(.selection, trigger: targetMinutes)
        .overlay(alignment: .bottom) {
            Text(targetMinutes.map(Self.shortText) ?? L("무제한"))
                .font(.pt(.footnote).weight(.semibold))
                .foregroundStyle(Color(white: 0.55))
                .offset(y: 18)
        }
        .padding(.bottom, 18)
    }

    /// 25 → "25:00", 90 → "1:30:00"
    static func clockText(_ minutes: Int) -> String {
        minutes < 60 ? String(format: "%02d:00", minutes) : String(format: "%d:%02d:00", minutes / 60, minutes % 60)
    }

    /// 칩에 쓰는 짧은 글: 40 → "40분", 70 → "1시간 10분"
    static func shortText(_ minutes: Int) -> String {
        if minutes < 60 { return L("\(minutes)분") }
        return minutes % 60 == 0 ? L("\(minutes / 60)시간") : L("\(minutes / 60)시간 \(minutes % 60)분")
    }

    // MARK: Running (가운데 제목 · 선 · 큰 숫자 · 선 / 아래 두 버튼)

    private var running: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 22) {
                if let lockUntil = studyTimer.lockUntil {
                    Label("다른 앱 잠금 중 · \(lockUntil.ui("a h:mm"))까지", systemImage: "lock.fill")
                        .font(.pt(.footnote).weight(.bold))
                        .foregroundStyle(Palette.danger)
                }
                if presence.isSessionActive {
                    PresenceLiveCard()
                    PresenceChip()
                }
                Text(studyTimer.title.loc)
                    .font(.pt(.title3).weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = studyTimer.elapsed(at: context.date)
                    VStack(spacing: 14) {
                        Rectangle().fill(line).frame(height: 1)
                        Text(TimeText.clock(elapsed))
                            .font(.pt(size: 72, weight: .bold).monospacedDigit())
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
                pillButton(title: studyTimer.phase == .running ? L("진행 중") : L("일시정지"),
                           symbol: studyTimer.phase == .running ? "pause.fill" : "play.fill",
                           iconColor: green) {
                    studyTimer.togglePause()
                    Haptics.tap()
                }
                pillButton(title: L("완료하기"), symbol: "stop.fill", iconColor: .white) {
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
                Label("목표 달성!", systemImage: "checkmark.seal.fill").font(.pt(.subheadline).weight(.semibold)).foregroundStyle(green)
            } else {
                Text("목표 \(TimeText.durationL(seconds: target)) · \(TimeText.durationL(seconds: target - Int(elapsed) + 59)) 남음")
                    .font(.pt(.subheadline)).foregroundStyle(Color(white: 0.55))
            }
        } else {
            Text(studyTimer.phase == .paused ? L("일시정지됨") : studyTimer.categoryName)
                .font(.pt(.subheadline)).foregroundStyle(Color(white: 0.55))
        }
    }

    /// 아래쪽 둥근 버튼: 왼쪽 동그란 아이콘 + 글자
    private func pillButton(title: String, symbol: String, iconColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.pt(size: 18, weight: .bold))
                    .foregroundStyle(iconColor)
                    .frame(width: 46, height: 46)
                    .background(Color.black, in: .circle)
                    .contentTransition(.symbolEffect(.replace))
                Text(title)
                    .font(.pt(.body).weight(.semibold))
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
            Image(systemName: seconds >= 10 ? "checkmark.seal.fill" : "clock.fill")
                .font(.pt(size: 64, weight: .bold))
                .foregroundStyle(seconds >= 10 ? green : Color(white: 0.5))
            VStack(spacing: 8) {
                Text(seconds >= 10 ? L("수고했어요!") : L("기록이 너무 짧아요"))
                    .font(.pt(.title).weight(.bold))
                Text(seconds >= 10 ? TimeText.clock(TimeInterval(seconds)) : L("10초 이상 공부해야 기록돼요."))
                    .font(seconds >= 10 ? .pt(size: 44, weight: .bold).monospacedDigit() : .body)
                    .foregroundStyle(seconds >= 10 ? Color.white : Color(white: 0.6))
                if seconds >= 10, let presenceSummary, presenceSummary.measuredSeconds >= 10 {
                    PresenceResultView(totalSeconds: seconds, summary: presenceSummary)
                        .padding(.top, 4)
                }
                if seconds >= 10, RankingService.shared.isJoined {
                    Text("랭킹에도 반영했어요").font(.pt(.subheadline)).foregroundStyle(Color(white: 0.6))
                }
            }
            Spacer()
            Button {
                savedSeconds = nil
                presenceSummary = nil
                studyTimer.isPresented = false
            } label: {
                Text("닫기")
                    .font(.pt(.body).weight(.bold))
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
                .font(.pt(.headline))
                .foregroundStyle(Theme.accent)

            VStack(alignment: .leading, spacing: 1) {
                if studyTimer.isActive {
                    Text(studyTimer.title.loc)
                        .font(.pt(.subheadline).weight(.semibold))
                        .lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(TimeText.clock(studyTimer.elapsed(at: context.date)))
                            .font(.pt(.caption).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("공부 시작")
                        .font(.pt(.subheadline).weight(.semibold))
                    if let nextPlanText {
                        Text(nextPlanText)
                            .font(.pt(.caption))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            if studyTimer.isActive {
                Button {
                    studyTimer.togglePause()
                } label: {
                    Image(systemName: studyTimer.phase == .running ? "pause.fill" : "play.fill")
                        .font(.pt(.headline))
                        .frame(width: 36, height: 36)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "play.fill")
                    .font(.pt(.headline))
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { studyTimer.isPresented = true }
    }

    /// 다음 공부 플랜 (없으면 한 줄만)
    private var nextPlanText: String? {
        let now = Date()
        guard let next = plans.occurrences(on: now).first(where: { $0.plan.isStudy && !$0.plan.isAllDay && $0.start > now }) else { return nil }
        return "\(next.start.ui("a h:mm")) · \(next.plan.title)"
    }
}

/// 집중 사운드 섞기: 소리 칩을 눌러 켜고, 켠 소리마다 음량 + 전체 음량
struct AmbientSoundSheet: View {
    @State private var sound = AmbientSoundPlayer.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(SoundKind.allCases) { kind in
                            chip(kind)
                        }
                    }

                    if !sound.mix.activeKinds.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(sound.mix.activeKinds) { kind in
                                levelRow(kind)
                                if kind != sound.mix.activeKinds.last { Divider().padding(.leading, 48) }
                            }
                        }
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 14, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "speaker").foregroundStyle(.secondary)
                        Slider(value: Binding(get: { Double(sound.master) }, set: { sound.master = Float($0) }), in: 0...1)
                            .accessibilityLabel("전체 음량")
                        Image(systemName: "speaker.wave.3").foregroundStyle(.secondary)
                    }
                    .font(.pt(.subheadline))
                    .padding(.horizontal, 4)
                }
                .padding(20)
                .animation(.snappy, value: sound.mix.on)
            }
            .navigationTitle("집중 사운드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if sound.isPlaying {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("멈춤") { sound.stop(); Haptics.tap() }
                    }
                } else if !sound.mix.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("재생") { sound.resume(); Haptics.tap() }
                    }
                }
            }
        }
    }

    /// 소리 칩: 동그란 파스텔 네모 + 이름 (켜면 색이 차오르고 아이콘이 살짝 움직임)
    private func chip(_ kind: SoundKind) -> some View {
        let isOn = sound.isOn(kind)
        let selected = sound.mix.isOn(kind)
        let color = Color(hex: kind.colorHex)
        return Button {
            sound.toggle(kind)
            Haptics.tap()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: kind.symbol)
                    .environment(\.symbolVariants, .none)
                    .font(.pt(size: 19, weight: .regular))
                    .foregroundStyle(isOn ? .white : color)
                    .frame(width: 52, height: 52)
                    .background(isOn ? color : color.pastel, in: .rect(cornerRadius: 14, style: .continuous))
                    .overlay {
                        if selected && !isOn {
                            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(color, lineWidth: 1.5)
                        }
                    }
                Text(kind.title.loc)
                    .font(.pt(.caption2).weight(.semibold))
                    .foregroundStyle(isOn ? Palette.ink : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(kind.title.loc)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func levelRow(_ kind: SoundKind) -> some View {
        let color = Color(hex: kind.colorHex)
        return HStack(spacing: 12) {
            Image(systemName: kind.symbol)
                .environment(\.symbolVariants, .none)
                .font(.pt(size: 14, weight: .regular))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.pastel, in: .rect(cornerRadius: 10, style: .continuous))
            Slider(value: Binding(get: { Double(sound.mix.level(kind)) }, set: { sound.setLevel(kind, Float($0)) }), in: 0...1)
                .tint(color)
                .accessibilityLabel("\(kind.title.loc) 음량")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
