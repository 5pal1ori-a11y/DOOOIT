import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var auth
    @AppStorage(SettingsKey.appearance) private var appearance = "system"
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if let user = auth.currentUser {
                    if user.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        NameSetupView()
                    } else {
                        MainTabView()
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
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

enum AppTab: Hashable {
    case home, study, planner, account
}

struct MainTabView: View {
    @Environment(StudyTimer.self) private var studyTimer
    @State private var tab: AppTab = .home
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
        .task {
            if AppSettings.notificationsEnabled {
                _ = await NotificationService.requestAuthorization()
            }
            PlanScheduler.shared.rescheduleNotifications()
        }
    }
}
