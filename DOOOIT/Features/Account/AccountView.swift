import SwiftData
import SwiftUI
import UserNotifications

struct AccountView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(StudyTimer.self) private var studyTimer
    @Environment(\.modelContext) private var context

    @Query private var sessions: [StudySession]
    @Query private var words: [Word]
    @Query private var notes: [MathNote]

    @AppStorage(SettingsKey.dailyWordGoal) private var wordGoal = 20
    @AppStorage(SettingsKey.dailyStudyGoalMinutes) private var studyGoalMinutes = 180
    @AppStorage(SettingsKey.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(SettingsKey.reminderLeadMinutes) private var leadMinutes = 10
    @AppStorage(SettingsKey.liveActivityEnabled) private var liveActivityEnabled = true
    @AppStorage(SettingsKey.autoStartTimer) private var autoStartTimer = true
    @AppStorage(SettingsKey.dDayTitle) private var dDayTitle = ""
    @AppStorage(SettingsKey.dDayDate) private var dDayDate: Double = 0

    @State private var showNameEdit = false
    @State private var nameDraft = ""
    @State private var showSignOut = false
    @State private var showDelete = false
    @State private var showResetRecords = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    profileHeader
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    statsRow
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    ThemePicker()
                } header: {
                    Text("화면")
                } footer: {
                    Text("바탕은 흰색이고, 버튼과 강조 색이 바뀌어요.")
                }

                Section("학습 목표") {
                    Stepper(value: $wordGoal, in: 5...200, step: 5) {
                        settingLabel("하루 단어 목표", value: "\(wordGoal)개", symbol: "character.book.closed.fill")
                    }
                    Stepper(value: $studyGoalMinutes, in: 30...720, step: 30) {
                        settingLabel("하루 공부 목표", value: TimeText.duration(minutes: studyGoalMinutes), symbol: "clock.fill")
                    }
                }

                Section {
                    TextField("목표 이름 (예: 수능, 기말고사)", text: $dDayTitle)
                    DatePicker("목표일", selection: dDayBinding, displayedComponents: .date)
                } header: {
                    Text("D-Day")
                } footer: {
                    Text("이름을 입력하면 홈 화면에 D-Day 카드가 나타나요.")
                }

                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("일정 알림", systemImage: "bell.badge.fill")
                    }
                    Picker(selection: $leadMinutes) {
                        Text("5분 전").tag(5)
                        Text("10분 전").tag(10)
                        Text("15분 전").tag(15)
                        Text("30분 전").tag(30)
                    } label: {
                        Label("미리 알림", systemImage: "alarm")
                    }
                    Toggle(isOn: $liveActivityEnabled) {
                        Label("다이나믹 아일랜드", systemImage: "capsule.fill")
                    }
                    Toggle(isOn: $autoStartTimer) {
                        Label("공부 타이머 자동 시작", systemImage: "timer")
                    }
                } header: {
                    Text("알림 및 타이머")
                } footer: {
                    Text("공부 카테고리 일정이 다가오면 다이나믹 아일랜드에 남은 시간을 보여주고, 시작 시간이 되면 타이머를 자동으로 실행해요.")
                }

                Section("플래너 · 통계") {
                    NavigationLink {
                        CategoryManagerView()
                    } label: {
                        Label("과목 · 카테고리 관리", systemImage: "tag.fill")
                    }
                    NavigationLink {
                        StatsView()
                    } label: {
                        Label("공부 통계", systemImage: "chart.pie.fill")
                    }
                }

                Section("정보") {
                    LabeledContent {
                        Text(appVersion)
                    } label: {
                        Label("버전", systemImage: "info.circle")
                    }
                    Button(role: .destructive) { showResetRecords = true } label: {
                        Label("공부 기록 초기화", systemImage: "arrow.counterclockwise")
                    }
                }

                Section {
                    Button { showSignOut = true } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .tint(.primary)
                    Button(role: .destructive) { showDelete = true } label: {
                        Label("계정 삭제", systemImage: "person.crop.circle.badge.xmark")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .tint(Theme.accent)
            .navigationTitle("계정")
            .onChange(of: notificationsEnabled) { _, enabled in
                Task {
                    if enabled { _ = await NotificationService.requestAuthorization() }
                    PlanScheduler.shared.rescheduleNotifications()
                }
            }
            .onChange(of: leadMinutes) { _, _ in PlanScheduler.shared.rescheduleNotifications() }
            .onChange(of: liveActivityEnabled) { _, enabled in
                if !enabled && !studyTimer.isActive { LiveActivityManager.shared.endAll() }
            }
            .alert("이름 변경", isPresented: $showNameEdit) {
                TextField("이름", text: $nameDraft)
                Button("취소", role: .cancel) {}
                Button("저장") { auth.updateName(nameDraft) }
            }
            .confirmationDialog("로그아웃할까요?", isPresented: $showSignOut, titleVisibility: .visible) {
                Button("로그아웃", role: .destructive) {
                    if studyTimer.isActive { studyTimer.stop() }
                    auth.signOut()
                }
            }
            .confirmationDialog("공부 기록을 모두 지울까요?", isPresented: $showResetRecords, titleVisibility: .visible) {
                Button("초기화", role: .destructive) {
                    try? context.delete(model: StudySession.self)
                    try? context.save()
                }
            } message: {
                Text("공부 시간 기록과 연속 공부 일수가 초기화돼요.")
            }
            .alert("계정을 삭제할까요?", isPresented: $showDelete) {
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive, action: deleteAccount)
            } message: {
                Text("플랜, 단어, 오답노트, 메모, 공부 기록이 모두 삭제되며 되돌릴 수 없어요.")
            }
        }
    }

    // MARK: Profile

    private var profileHeader: some View {
        let user = auth.currentUser
        return HStack(spacing: 16) {
            Text(String(user?.name.prefix(1) ?? "D"))
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Theme.accent)
                .frame(width: 68, height: 68)
                .background(Color.white, in: .circle)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 3).padding(-4))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user?.name ?? "")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white)
                    Button {
                        nameDraft = user?.name ?? ""
                        showNameEdit = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                if let email = user?.email, !email.isEmpty {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                if let provider = user?.provider {
                    TagLabel(text: provider.title, symbol: provider.symbol, color: .white)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                AccentGradient.linear
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 150, height: 150)
                    .offset(x: 50, y: -60)
            }
            .clipShape(.rect(cornerRadius: 26))
        }
        .shadow(color: Theme.accent.opacity(0.28), radius: 14, y: 8)
        .padding(.bottom, 6)
    }

    private var statsRow: some View {
        let totalMinutes = sessions.reduce(0) { $0 + $1.seconds } / 60
        let learned = words.filter(\.isLearned).count
        return HStack(spacing: 0) {
            stat(value: TimeText.duration(minutes: totalMinutes), label: "총 공부 시간")
            Divider().frame(height: 36)
            stat(value: "\(learned)", label: "외운 단어")
            Divider().frame(height: 36)
            stat(value: "\(notes.count)", label: "오답노트")
        }
        .softCard(cornerRadius: 22, padding: 16)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func settingLabel(_ title: String, value: String, symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: Helpers

    private var dDayBinding: Binding<Date> {
        Binding(
            get: { dDayDate > 0 ? Date(timeIntervalSince1970: dDayDate) : Date().adding(days: 30) },
            set: { dDayDate = $0.startOfDay.timeIntervalSince1970 }
        )
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func deleteAccount() {
        if studyTimer.isActive { studyTimer.stop() }
        try? context.delete(model: Plan.self)
        try? context.delete(model: Word.self)
        try? context.delete(model: MathNote.self)
        try? context.delete(model: Memo.self)
        try? context.delete(model: StudySession.self)
        try? context.delete(model: ExamPlan.self)
        try? context.delete(model: StudyContent.self)
        try? context.delete(model: QuizRecord.self)
        try? context.delete(model: AIQuestion.self)
        try? context.save()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        LiveActivityManager.shared.endAll()
        auth.deleteAccount()
    }
}
