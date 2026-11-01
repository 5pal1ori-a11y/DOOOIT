import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // 앱이 켜져 있을 때도 배너 표시
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    // 알림을 눌러서 들어오면 공부 일정의 타이머를 자동으로 시작
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        // 주간 리포트 알림 → 리포트 화면 열기
        if info["weeklyReport"] as? Bool == true || response.notification.request.identifier == "weekly.report" {
            Task { @MainActor in
                AppRouter.shared.showWeeklyReport = true
            }
        }
        if let idString = info["planID"] as? String,
           let planID = UUID(uuidString: idString),
           let isStudy = info["isStudy"] as? Bool, isStudy {
            Task { @MainActor in
                PlanScheduler.shared.startFromNotification(planID: planID)
            }
        }
        completionHandler()
    }
}
