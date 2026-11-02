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
    @AppStorage(AppearanceMode.key) private var appearanceRaw = AppearanceMode.system.rawValue

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
                        .appearAnimation()
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    statsRow
                        .appearAnimation(delay: 0.08)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section("목표") {
                    Stepper(value: $studyGoalMinutes, in: 30...720, step: 30) {
                        settingLabel("하루 공부", value: TimeText.duration(minutes: studyGoalMinutes), symbol: "clock.fill", color: Theme.accent)
                    }
                    Stepper(value: $wordGoal, in: 5...200, step: 5) {
                        settingLabel("하루 단어", value: "\(wordGoal)개", symbol: "character.book.closed.fill", color: Color(hex: "#5AC8FA"))
                    }
                }

                Section {
                    NavigationLink { notificationSettings } label: {
                        HStack(spacing: 12) {
                            icon("bell.badge.fill", Palette.danger)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("알림 설정").foregroundStyle(Palette.ink)
                                Text("탭하여 설정").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("앱") {
                    Picker(selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases) { Text($0.title).tag($0.rawValue) }
                    } label: { item("화면 모드", "circle.lefthalf.filled", Color(hex: "#1F2433")) }
                    .pickerStyle(.menu)
                    ThemePicker()
                    NavigationLink { CategoryManagerView() } label: { item("과목 · 카테고리", "tag.fill", Color(hex: "#AF52DE")) }
                    NavigationLink { StatsView() } label: { item("공부 통계", "chart.bar.fill", Theme.accent) }
                    NavigationLink { RankingView() } label: { item("공부 랭킹", "trophy.fill", Color(hex: "#FF7A45")) }
                }

                Section {
                    NavigationLink { accountSettings } label: {
                        HStack(spacing: 12) {
                            icon("person.crop.circle.badge.checkmark", Color.gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("계정 설정").foregroundStyle(Palette.ink)
                                Text("버전 \(appVersion)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
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
        }
    }

    // MARK: 하위 화면

    /// 알림 설정: 일정 알림 · 미리 알림 · 다이나믹 아일랜드 · 타이머 자동 시작
    private var notificationSettings: some View {
        List {
            Section {
                Toggle(isOn: $notificationsEnabled) { item("일정 알림", "bell.badge.fill", Palette.danger) }
                Picker(selection: $leadMinutes) {
                    Text("5분 전").tag(5)
                    Text("10분 전").tag(10)
                    Text("15분 전").tag(15)
                    Text("30분 전").tag(30)
                } label: { item("미리 알림", "alarm.fill", Palette.warning) }
                Toggle(isOn: $liveActivityEnabled) { item("다이나믹 아일랜드", "capsule.fill", Color(hex: "#1F2433")) }
                Toggle(isOn: $autoStartTimer) { item("타이머 자동 시작", "timer", Palette.success) }
            }
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .tint(Theme.accent)
        .navigationTitle("알림 설정")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 계정 설정: 버전 · 공부 기록 초기화 · 로그아웃 · 계정 삭제
    private var accountSettings: some View {
        List {
            Section {
                LabeledContent { Text(appVersion) } label: { item("버전", "info", Color.gray) }
            }
            Section {
                Button { showResetRecords = true } label: { item("공부 기록 초기화", "arrow.counterclockwise", Color.gray) }
                    .tint(.primary)
                Button { showSignOut = true } label: { item("로그아웃", "rectangle.portrait.and.arrow.right", Color.gray) }
                    .tint(.primary)
            }
            Section {
                Button(role: .destructive) { showDelete = true } label: {
                    Text("계정 삭제").frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .tint(Theme.accent)
        .navigationTitle("계정 설정")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: Profile

    /// 프로필 카드 (흰 카드 · 동그란 이니셜 · 이름 · 로그인 방식)
    private var profileHeader: some View {
        let user = auth.currentUser
        return HStack(spacing: 16) {
            Text(String(user?.name.prefix(1) ?? "D"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Theme.accent, in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(user?.name ?? "")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.ink)
                if let email = user?.email, !email.isEmpty {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let provider = user?.provider {
                    TagLabel(text: provider.title, symbol: provider.symbol, color: .secondary)
                }
            }
            Spacer(minLength: 0)
            Button {
                nameDraft = user?.name ?? ""
                showNameEdit = true
            } label: {
                Text("편집")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.06), in: .capsule)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.ink)
        }
        .softCard(cornerRadius: 22, padding: 18)
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
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func settingLabel(_ title: String, value: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            icon(symbol, color)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// iOS 설정 앱처럼 색깔 네모 아이콘 + 제목
    private func item(_ title: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            icon(symbol, color)
            Text(title).foregroundStyle(Palette.ink)
        }
    }

    private func icon(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(color, in: .rect(cornerRadius: 7))
    }

    // MARK: Helpers

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
        try? context.delete(model: WeakConcept.self)
        try? context.save()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        LiveActivityManager.shared.endAll()
        // 앱 잠금(스크린 타임) 해제와 예약된 잠금 일정 정리
        AppLockManager.shared.endLock(planKey: nil)
        AppLockManager.shared.scheduleLocks(for: [])
        // 개인 설정(D-Day 등)과 대화 기록, 위젯 정보도 지움
        for key in [SettingsKey.dDayTitle, SettingsKey.dDayDate, SettingsKey.wordGoalDoneKey, "selectedTab"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        DoitAssistant.shared.reset()
        WidgetSync.update(context: context)
        // 이 계정의 저장소 폴더는 다른 저장소로 바꾼 뒤 지움
        if let id = auth.currentUser?.id { AccountStore.scheduleRemoval(of: id) }
        auth.deleteAccount()
    }
}
