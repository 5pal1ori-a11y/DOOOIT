import Observation
import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var auth
    @AppStorage(SettingsKey.themeColor) private var themeRaw = ThemeColor.lavender.rawValue
    @AppStorage(AppearanceMode.key) private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
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
        .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
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

    /// 탭 바는 아이콘만 (이름은 VoiceOver로 읽어 줌): 얇고 둥근 선 모양 (탭 바가 저절로 채운 모양으로 바꾸지 않게 막음),
    /// 고른 탭은 진한 색 · 나머지는 회색
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
                tabIcon("홈", "house")
            }
            Tab(value: AppTab.study) {
                StudyView().tint(Theme.accent)
            } label: {
                tabIcon("학습", "book")
            }
            Tab(value: AppTab.ai) {
                DoitAIView().tint(Theme.accent)
            } label: {
                tabIcon("두잇 AI", "sparkles")
            }
            Tab(value: AppTab.planner) {
                PlannerView().tint(Theme.accent)
            } label: {
                tabIcon("플래너", "calendar")
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
            switch url.host() {
            case "planner":
                plannerRouter.selectedDate = Date().startOfDay
                tab = .planner
            case "words": tab = .study
            case "home": tab = .home
            case "weekly-report": router.showWeeklyReport = true
            default: break
            }
        }
        .task {
            // 랭킹에 참여 중이면 Game Center에 로그인해 둠 (타이머를 마치면 바로 반영되게)
            if RankingService.shared.isJoined { RankingService.shared.authenticate() }
            if AppSettings.notificationsEnabled {
                _ = await NotificationService.requestAuthorization()
            }
            PlanScheduler.shared.rescheduleNotifications()
        }
    }
}
