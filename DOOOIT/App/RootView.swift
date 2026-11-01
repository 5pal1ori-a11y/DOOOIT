import Observation
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
        .preferredColorScheme(.light)
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

    var body: some View {
        @Bindable var studyTimer = studyTimer
        @Bindable var router = router

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
        }
        // 홈 화면 위젯을 누르면 해당 탭으로
        .onOpenURL { url in
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
            if AppSettings.notificationsEnabled {
                _ = await NotificationService.requestAuthorization()
            }
            PlanScheduler.shared.rescheduleNotifications()
        }
    }
}
