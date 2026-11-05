import Observation
import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var auth
    @AppStorage(SettingsKey.themeColor) private var themeRaw = ThemeColor.standard.rawValue
    @AppStorage(AppearanceMode.key) private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var showSplash: Bool = {
        #if DEBUG
        if UIShot.isActive { return false }
        #endif
        return true
    }()

    var body: some View {
        ZStack {
            Group {
                #if DEBUG
                if let screen = UIShot.screen, screen.isWidgetGallery {
                    WidgetGalleryView(page: screen)
                } else {
                    accountContent
                }
                #else
                accountContent
                #endif
            }
            .animation(.smooth(duration: 0.4), value: auth.currentUser)

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.55)) { showSplash = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.08)))
                .zIndex(10)
            }
        }
        .tint(Theme.accent)
        // 앱 전체 기본 글꼴: Pretendard
        .font(.pt(.body))
        .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
    }

    @ViewBuilder
    private var accountContent: some View {
        if let user = auth.currentUser {
            if user.name.trimmingCharacters(in: .whitespaces).isEmpty {
                NameSetupView()
            } else {
                MainTabView()
                    // 테마를 바꾸거나 계정이 바뀌면 탭 화면 전체를 다시 그림 (새 색, 그 계정의 저장소)
                    .id("\(themeRaw)-\(user.id)")
            }
        } else {
            AuthView()
        }
    }
}

enum AppTab: String, Hashable {
    case home, study, ai, planner, account
}

/// 알림·위젯에서 특정 화면을 바로 여는 요청 (앱이 꺼져 있다가 켜져도 유지됨)
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    /// 주간 AI 리포트 열기
    var showWeeklyReport = false
}

struct MainTabView: View {
    @Environment(StudyTimer.self) private var studyTimer
    @AppStorage("selectedTab") private var tab: AppTab = .home
    @State private var plannerRouter = PlannerRouter()
    @State private var router = AppRouter.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    /// 달력 아이콘에 적는 오늘 날짜 (앱을 다시 열 때 바뀌었으면 새로 그림)
    @State private var today = Calendar.current.component(.day, from: Date())

    /// 탭 바는 아이콘만 (이름은 VoiceOver로 읽어 줌): 얇고 둥근 선 모양 (탭 바가 저절로 채운 모양으로 바꾸지 않게 막음),
    /// 고른 탭은 진한 색 · 나머지는 회색
    /// 직접 그린 아이콘 (집 · 기울어진 책 · 오늘 날짜 달력)
    private func drawnIcon(_ title: String, _ image: UIImage) -> some View {
        Image(uiImage: image)
            .accessibilityLabel(title)
    }

    private func tabIcon(_ title: String, _ symbol: String) -> some View {
        Image(systemName: symbol)
            .environment(\.symbolVariants, .none)
            .fontWeight(.regular)
            .accessibilityLabel(title)
    }

    var body: some View {
        @Bindable var studyTimer = studyTimer
        @Bindable var router = router

        TabView(selection: $tab) {
            Tab(value: AppTab.home) {
                HomeView(selectedTab: $tab).tint(Theme.accent)
            } label: {
                drawnIcon("홈", TabIcons.home())
            }
            Tab(value: AppTab.study) {
                StudyView().tint(Theme.accent)
            } label: {
                drawnIcon("학습", TabIcons.book())
            }
            Tab(value: AppTab.ai) {
                DoitAIView().tint(Theme.accent)
            } label: {
                tabIcon("모티 AI", "sparkles")
            }
            Tab(value: AppTab.planner) {
                PlannerView().tint(Theme.accent)
            } label: {
                drawnIcon("플래너", TabIcons.calendar(day: today))
            }
            Tab(value: AppTab.account) {
                AccountView().tint(Theme.accent)
            } label: {
                tabIcon("계정", "person")
            }
        }
        // 탭 바의 고른 아이콘은 진한 글자색 (화면 안 버튼들은 각 탭에서 다시 보라색으로)
        .tint(Palette.ink)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                today = Calendar.current.component(.day, from: Date())
                BadgeCenter.shared.check(context: context)
            }
        }
        // 공부를 마치고 타이머를 닫을 때 · 탭을 옮길 때 새 배지 확인
        .onChange(of: studyTimer.isPresented) { _, shown in
            if !shown { BadgeCenter.shared.check(context: context) }
        }
        .onChange(of: studyTimer.phase) { _, phase in
            if phase == .idle && !studyTimer.isPresented { BadgeCenter.shared.check(context: context) }
        }
        .onChange(of: tab) { BadgeCenter.shared.check(context: context) }
        // 새 배지 축하 (어느 탭에서든 위에서 살짝)
        .overlay(alignment: .top) {
            BadgeToastHost()
        }
        .tabViewBottomAccessory {
            TimerAccessoryView().tint(Theme.accent)
        }
        .environment(plannerRouter)
        .fullScreenCover(isPresented: $studyTimer.isPresented) {
            TimerView().tint(Theme.accent)
        }
        // 주간 리포트 알림을 누르면 어느 화면에서든 리포트를 바로 보여줌
        .sheet(isPresented: $router.showWeeklyReport) {
            NavigationStack {
                WeeklyReportView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { router.showWeeklyReport = false } label: { Image(systemName: "xmark") }
                                .accessibilityLabel("닫기")
                        }
                    }
            }
            .tint(Theme.accent)
        }
        // 홈 화면 위젯을 누르면 해당 탭으로
        .onOpenURL { url in
            if AuthManager.handleGoogleURL(url) { return }
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            switch url.host() {
            case "planner":
                // 달력 위젯에서 누른 날 (없으면 오늘)
                let day = query.first { $0.name == "date" }?.value.flatMap { KoreanDate.dayKeyFormatter.date(from: $0) }
                plannerRouter.selectedDate = (day ?? Date()).startOfDay
                tab = .planner
            case "timer":
                // 바로 공부 위젯: start=분 (0이면 시간 제한 없이) · 이미 공부 중이면 그 타이머를 보여 줌
                if !studyTimer.isActive, let value = query.first(where: { $0.name == "start" })?.value, let minutes = Int(value) {
                    let study = ((try? context.fetch(FetchDescriptor<PlanCategory>())) ?? [])
                        .filter(\.isStudy).sorted { $0.sortIndex < $1.sortIndex }
                    studyTimer.start(title: "자유 공부", categoryName: study.first?.name ?? "공부",
                                     symbol: study.first?.symbol ?? "book.fill",
                                     targetMinutes: minutes > 0 ? min(minutes, 12 * 60) : nil)
                }
                studyTimer.isPresented = true
            case "words": tab = .study
            case "home": tab = .home
            case "weekly-report": router.showWeeklyReport = true
            default: break
            }
        }
        .task {
            BadgeCenter.shared.check(context: context)
            #if DEBUG
            if UIShot.isActive { return }
            #endif
            // 랭킹에 참여 중이면 Game Center에 로그인해 둠 (타이머를 마치면 바로 반영되게)
            if RankingService.shared.isJoined { RankingService.shared.authenticate() }
            if AppSettings.notificationsEnabled {
                _ = await NotificationService.requestAuthorization()
            }
            PlanScheduler.shared.rescheduleNotifications()
        }
    }
}
