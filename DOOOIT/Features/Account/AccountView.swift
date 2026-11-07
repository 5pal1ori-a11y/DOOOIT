import AuthenticationServices
import PhotosUI
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
    @AppStorage(SettingsKey.soundEffects) private var soundEffects = true
    @AppStorage(SettingsKey.schoolSelection) private var schoolRaw = ""
    @AppStorage(AppearanceMode.key) private var appearanceRaw = AppearanceMode.system.rawValue
    /// 화면 언어: 고른 값 (적용은 안내 창에서 확인한 뒤)
    @State private var languagePick = AppLanguage.selected
    @State private var pendingLanguage: AppLanguage?

    @State private var showNameEdit = false
    /// 프로필 사진 고르기 · 바꾼 뒤 다시 그리기
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoMenu = false
    @State private var showPhotoPicker = false
    @State private var photoVersion = 0
    @State private var nameDraft = ""
    @State private var showSignOut = false
    @State private var showDelete = false
    @State private var showResetRecords = false
    /// iCloud 동기화 (같은 Apple ID 기기끼리)
    @State private var syncOn = false
    /// 둘러보기에서 Apple 로그인 실패 안내
    @State private var guestSignInError: String?
    /// iCloud(CloudKit) 계정을 쓸 수 있는지 (화면이 뜰 때 다시 확인)
    @State private var cloudAvailable = AccountStore.iCloudAvailable
    @State private var confirmSyncTakeover = false
    @State private var badges = BadgeCenter.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    profileHeader
                        .staggerIn(index: 0)
                    if auth.isGuest { guestCard }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    statsRow
                        .staggerIn(index: 1)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    NavigationLink { BadgeShelfView() } label: {
                        HStack(spacing: 12) {
                            icon("rosette", Palette.butter)
                            Text("배지").foregroundStyle(Palette.ink)
                            Spacer()
                            Text("\(BadgeBook.all.filter { badges.isUnlocked($0) }.count) / \(BadgeBook.all.count)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Section("목표") {
                    Stepper(value: $studyGoalMinutes, in: 30...720, step: 30) {
                        settingLabel("하루 공부", value: TimeText.durationL(minutes: studyGoalMinutes), symbol: "clock.fill", color: Theme.accent)
                    }
                    Stepper(value: $wordGoal, in: 5...200, step: 5) {
                        settingLabel("하루 단어", value: L("\(wordGoal)개"), symbol: "book.closed.fill", color: Palette.sky)
                    }
                }

                Section {
                    NavigationLink { SchoolSetupView() } label: {
                        let school = SchoolSelection.decode(schoolRaw)
                        HStack(spacing: 12) {
                            icon("graduationcap", Theme.accent)
                            Text("학교 정보").foregroundStyle(Palette.ink)
                            Spacer()
                            Text(school.map { "\($0.school.name) · \(L("\($0.grade)학년 \($0.classNum)반"))" } ?? L("설정 안 함"))
                                .font(.pt(.subheadline))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Section {
                    NavigationLink { notificationSettings } label: { item("알림", "bell.fill", Palette.pink) }
                }

                Section {
                    NavigationLink { appSettings } label: { item("앱", "square.grid.2x2", Color.indigo) }
                }

                Section {
                    NavigationLink { accountSettings } label: { item("계정 설정", "person.fill", Color.gray) }
                }
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .tint(Theme.accent)
            .navigationTitle("계정")
            #if DEBUG
            .uiShotPush(.accountSettings) { accountSettings }
            .uiShotPush(.badges) { BadgeShelfView() }
            .uiShotPush(.appSettings) { appSettings }
            #endif
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
                Toggle(isOn: $notificationsEnabled) { item("일정 알림", "bell.fill", Palette.pink) }
                Picker(selection: $leadMinutes) {
                    Text("5분 전").tag(5)
                    Text("10분 전").tag(10)
                    Text("15분 전").tag(15)
                    Text("30분 전").tag(30)
                } label: { item("미리 알림", "alarm.fill", Palette.butter) }
                Toggle(isOn: $liveActivityEnabled) { item("다이나믹 아일랜드", "capsule.fill", Color.indigo) }
                Toggle(isOn: $autoStartTimer) { item("타이머 자동 시작", "timer", Palette.mint) }
            }
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .tint(Theme.accent)
        .navigationTitle("알림 설정")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 앱: 화면 모드 · 테마 · 과목·카테고리 · 공부 통계 · 공부 랭킹 (한 줄로 묶고 눌러서 들어감)
    private var appSettings: some View {
        List {
            Section {
                Picker(selection: $appearanceRaw) {
                    ForEach(AppearanceMode.allCases) { Text($0.title).tag($0.rawValue) }
                } label: { item("화면 모드", "circle.lefthalf.filled", Color.indigo) }
                .pickerStyle(.menu)
                ThemePicker()
                Picker(selection: Binding(get: { languagePick }, set: { pickLanguage($0) })) {
                    ForEach(AppLanguage.allCases) { Text(verbatim: $0.displayName).tag($0) }
                } label: { item("언어", "globe", Palette.sky) }
                .pickerStyle(.menu)
                Toggle(isOn: $soundEffects) { item("효과음", "speaker.wave.2.fill", Palette.mint) }
            }
            Section {
                NavigationLink { CategoryManagerView() } label: { item("과목 · 카테고리", "tag.fill", Palette.pink) }
                NavigationLink { StatsView() } label: { item("공부 통계", "chart.bar.fill", Theme.accent) }
                if auth.isGuest {
                    // 둘러보기: 랭킹은 로그인 뒤에
                    LabeledContent { Image(systemName: "lock.fill").foregroundStyle(.tertiary) } label: {
                        item("공부 랭킹 (로그인 필요)", "trophy.fill", Palette.peach)
                    }
                } else {
                    NavigationLink { RankingView() } label: { item("공부 랭킹", "trophy.fill", Palette.peach) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .tint(Theme.accent)
        .navigationTitle("앱")
        .navigationBarTitleDisplayMode(.inline)
        // 언어 바꾸기 안내 (새 언어로 보여 줌)
        .alert(pendingLanguage.map { AppLanguage.text("언어를 바꿀게요", in: $0) } ?? "", isPresented: Binding(
            get: { pendingLanguage != nil }, set: { if !$0 { pendingLanguage = nil } })) {
            Button(pendingLanguage.map { AppLanguage.text("확인", in: $0) } ?? "") { applyLanguage() }
            Button(pendingLanguage.map { AppLanguage.text("취소", in: $0) } ?? "", role: .cancel) {
                languagePick = AppLanguage.selected
            }
        } message: {
            Text(verbatim: pendingLanguage.map { AppLanguage.text("앱을 다시 열면 위젯·알림까지 모두 바뀌어요.", in: $0) } ?? "")
        }
    }

    /// 언어를 고르면: 먼저 새 언어로 안내를 보여 주고, 확인하면 저장 + 화면을 바로 그 언어로
    private func pickLanguage(_ language: AppLanguage) {
        languagePick = language
        guard language != AppLanguage.selected else { return }
        pendingLanguage = language
    }

    private func applyLanguage() {
        guard let language = pendingLanguage else { return }
        pendingLanguage = nil
        AppLanguage.set(language)
        DoitMind.replyLanguage = AppLanguage.code
        // 알림·위젯 글자도 새 언어로
        PlanScheduler.shared.rescheduleNotifications()
        WidgetSync.update(context: context)
    }

    /// 계정 설정: 버전 · 공부 기록 초기화 · 로그아웃 · 계정 삭제
    private var accountSettings: some View {
        List {
            if AccountStore.syncReady, auth.isGuest {
                Section {
                    LabeledContent { Image(systemName: "lock.fill").foregroundStyle(.tertiary) } label: {
                        item("iCloud 동기화", "icloud", Palette.sky)
                    }
                } footer: {
                    Text("Apple로 로그인하면 쓸 수 있어요")
                }
            }
            if AccountStore.syncReady, !auth.isGuest {
            Section {
                Toggle(isOn: Binding(get: { syncOn }, set: { changeSync($0) })) {
                    item("iCloud 동기화", "icloud", Palette.sky)
                }
                .disabled(!cloudAvailable && !syncOn)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(cloudAvailable ? L("같은 Apple ID 기기끼리 기록이 이어져요") : L("iPhone 설정에서 iCloud에 로그인하면 켤 수 있어요"))
                    // 동기화 상태 (문제를 찾을 때 보려고, 2초마다 다시 읽음)
                    if syncOn {
                        TimelineView(.periodic(from: .now, by: 2)) { _ in
                            Text(AccountStore.syncStatus.prefix(4).joined(separator: "\n"))
                                .font(.pt(.caption2))
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            }
            Section {
                LabeledContent { Text(appVersion) } label: { item("버전", "info", Color.gray) }
                NavigationLink { LegalDocumentView(kind: .terms) } label: { item("이용약관", "doc.text", Color.gray) }
                NavigationLink { LegalDocumentView(kind: .privacy) } label: { item("개인정보 처리방침", "hand.raised", Color.gray) }
            }
            Section {
                Button { showResetRecords = true } label: { item("공부 기록 초기화", "arrow.counterclockwise", Color.gray) }
                    .tint(.primary)
                Button { showSignOut = true } label: {
                    item(auth.isGuest ? "둘러보기 끝내기" : "로그아웃", "rectangle.portrait.and.arrow.right", Color.gray)
                }
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
        .onAppear { syncOn = AccountStore.isSyncEnabled(for: auth.currentUser?.id) }
        .task { cloudAvailable = await AccountStore.refreshCloudAccount() }
        .confirmationDialog("다른 계정이 이 기기에서 iCloud를 쓰고 있어요", isPresented: $confirmSyncTakeover, titleVisibility: .visible) {
            Button("이 계정으로 바꾸기") { applySync(true) }
        } message: {
            Text("한 기기에서는 한 계정만 iCloud로 이어져요.")
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

    // MARK: Profile

    /// 둘러보기 중: Apple로 로그인하면 지금까지 쓴 기록을 그대로 이어받음
    private var guestCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("로그인 없이 쓰는 중이에요")
                .font(.pt(.subheadline).weight(.bold))
                .foregroundStyle(Palette.ink)
            Text("기록은 이 기기에만 저장돼요. Apple로 로그인하면 지금 기록 그대로 iCloud 동기화와 랭킹을 쓸 수 있어요.")
                .font(.pt(.caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                do { try auth.handleAppleSignIn(result) } catch { guestSignInError = error.localizedDescription }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 46)
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
        }
        .softCard(cornerRadius: 22, padding: 18)
        .errorAlert($guestSignInError, title: L("로그인 실패"))
    }

    /// 프로필 카드 (흰 카드 · 동그란 이니셜 · 이름 · 로그인 방식)
    private var profileHeader: some View {
        let user = auth.currentUser
        return HStack(spacing: 16) {
            Button { showPhotoMenu = true } label: {
                ProfileAvatar(accountID: user?.id ?? "", name: user?.name ?? "D", size: 60, version: photoVersion)
                    .padding(3)
                    .background(Theme.accent.pastel, in: .circle)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.pt(size: 10, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 22, height: 22)
                            .background(Theme.accent, in: .circle)
                            .overlay(Circle().strokeBorder(Palette.card, lineWidth: 2))
                    }
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("프로필 사진 바꾸기")
            .confirmationDialog("프로필 사진", isPresented: $showPhotoMenu, titleVisibility: .visible) {
                Button("앨범에서 고르기") { showPhotoPicker = true }
                if ProfilePhotoStore.load(for: user?.id ?? "") != nil {
                    Button("사진 지우기", role: .destructive) {
                        ProfilePhotoStore.remove(for: user?.id ?? "")
                        photoVersion += 1
                    }
                }
                Button("취소", role: .cancel) {}
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) {
                guard let item = photoItem, let id = auth.currentUser?.id else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), ProfilePhotoStore.save(data, for: id) {
                        photoVersion += 1
                        Haptics.success()
                    }
                    photoItem = nil
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(user?.name.loc ?? "")
                    .font(.pt(.title3).weight(.bold))
                    .foregroundStyle(Palette.ink)
                if let email = user?.email, !email.isEmpty {
                    Text(email)
                        .font(.pt(.subheadline))
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
                    .font(.pt(.subheadline).weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: Radius.chip + 2, style: .continuous))
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
            StatColumn(value: TimeText.durationL(minutes: totalMinutes), label: L("총 공부 시간")).padding(.horizontal, 8)
            Rectangle().fill(Palette.line).frame(width: 0.5, height: 36)
            StatColumn(value: "\(learned)", label: L("외운 단어")).padding(.horizontal, 8)
            Rectangle().fill(Palette.line).frame(width: 0.5, height: 36)
            StatColumn(value: "\(notes.count)", label: L("오답노트")).padding(.horizontal, 8)
        }
        .softCard(padding: 14)
    }

    private func settingLabel(_ title: LocalizedStringKey, value: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            icon(symbol, color)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .numberRoll(value)
        }
    }

    /// 단색 아이콘 + 제목
    private func item(_ title: LocalizedStringKey, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            icon(symbol, color)
            Text(title).foregroundStyle(Palette.ink)
        }
    }

    private func icon(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol.outlineSymbol)
            .environment(\.symbolVariants, .none)
            .font(.pt(size: 17, weight: .regular))
            .foregroundStyle(Palette.ink.opacity(0.62))
            .frame(width: 24)
    }

    // MARK: Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// 동기화 켜기·끄기 (다른 계정이 쓰고 있으면 먼저 물어봄)
    private func changeSync(_ on: Bool) {
        if on, AccountStore.syncOwnedByOther(than: auth.currentUser?.id) { confirmSyncTakeover = true; return }
        applySync(on)
    }

    private func deleteEach<T: PersistentModel>(_ type: T.Type) {
        for item in (try? context.fetch(FetchDescriptor<T>())) ?? [] { context.delete(item) }
    }

    private func applySync(_ on: Bool) {
        guard let id = auth.currentUser?.id else { return }
        syncOn = on
        Haptics.tap()
        AccountStore.setSync(on, for: id)
    }

    private func deleteAccount() {
        if studyTimer.isActive { studyTimer.stop() }
        // iCloud로 이어 쓰던 계정: 하나씩 지워야 iCloud에서도 지워짐 (한꺼번에 지우기는 iCloud로 전해지지 않음)
        if AccountStore.isSyncEnabled(for: auth.currentUser?.id) {
            deleteEach(Plan.self); deleteEach(PlanCategory.self); deleteEach(Word.self); deleteEach(MathNote.self); deleteEach(Memo.self)
            deleteEach(StudySession.self); deleteEach(ExamPlan.self); deleteEach(StudyContent.self); deleteEach(QuizRecord.self)
            deleteEach(AIQuestion.self); deleteEach(WeakConcept.self)
            try? context.save()
            if let id = auth.currentUser?.id { AccountStore.clearSync(for: id) }
        }
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
