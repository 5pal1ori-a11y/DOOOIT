import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var auth
    @AppStorage(SettingsKey.themeColor) private var themeRaw = ThemeColor.lavender.rawValue
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if let user = auth.currentUser {
                    if user.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        NameSetupView()
                    } else {
                        MainTabView()
                            .id(themeRaw) // 테마를 바꾸면 탭 화면 전체를 새 색으로 다시 그림
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
        .preferredColorScheme(.light)
    }
}

enum AppTab: String, Hashable {
    case home, study, ai, planner, account
}

struct MainTabView: View {
    @Environment(StudyTimer.self) private var studyTimer
    @AppStorage("selectedTab") private var tab: AppTab = .home
    @State private var plannerRouter = PlannerRouter()

    var body: some View {
        @Bindable var studyTimer = studyTimer

        TabView(selection: $tab) {
            Tab("홈", systemImage: "house.fill", value: AppTab.home) {
                HomeView(selectedTab: $tab)
            }
            Tab("공부", systemImage: "book.closed.fill", value: AppTab.study) {
                StudyView()
            }
            Tab("두잇 AI", systemImage: "sparkles", value: AppTab.ai) {
                DoitAIView()
            }
            Tab("플래너", systemImage: "calendar", value: AppTab.planner) {
                PlannerView()
            }
            Tab("계정", systemImage: "person.crop.circle.fill", value: AppTab.account) {
                AccountView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            TimerAccessoryView()
        }
        .environment(plannerRouter)
        .fullScreenCover(isPresented: $studyTimer.isPresented) {
            TimerView()
        }
        // 홈 화면 위젯을 누르면 해당 탭으로
        .onOpenURL { url in
            switch url.host() {
            case "planner":
                plannerRouter.selectedDate = Date().startOfDay
                tab = .planner
            case "words": tab = .study
            case "home": tab = .home
            default: break
            }
        }
        .task {
            if AppSettings.notificationsEnabled {
                _ = await NotificationService.requestAuthorization()
            }
            PlanScheduler.shared.rescheduleNotifications()
        }
    }
}
