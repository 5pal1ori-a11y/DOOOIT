import Foundation
import UserNotifications

/// 일정 알림 (시작 N분 전 / 시작 시각)
enum NotificationService {
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// iOS는 앱당 예약 알림이 64개로 제한되므로 가까운 30개 일정만 예약
    static func reschedule(plans: [Plan]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard AppSettings.notificationsEnabled else { return }
        WeeklyReportBuilder.scheduleNotification()

        let now = Date()
        let lead = AppSettings.leadMinutes
        var upcoming: [PlanOccurrence] = []
        for offset in 0..<14 {
            let day = now.startOfDay.adding(days: offset)
            upcoming += plans.occurrences(on: day).filter { !$0.plan.isAllDay && $0.start > now }
        }
        upcoming.sort { $0.start < $1.start }

        for occurrence in upcoming.prefix(30) {
            let plan = occurrence.plan
            let info: [String: Any] = [
                "planID": plan.id.uuidString,
                "dayKey": occurrence.day.dayKey,
                "isStudy": plan.isStudy
            ]

            // 공부 플랜: 설정의 미리 알림 / 일반 플랜: 플랜마다 정한 알림 (-1 없음, 0 정시)
            let planLead = plan.isStudy ? lead : plan.reminderMinutes
            if !plan.isStudy && planLead < 0 { continue }

            let leadDate = occurrence.start.addingTimeInterval(-Double(planLead * 60))
            if planLead > 0 && leadDate > now {
                add(
                    id: "lead.\(occurrence.id)",
                    title: "\(planLead)분 후 \(plan.title)",
                    body: plan.isStudy
                        ? (plan.lockApps ? "곧 공부 시간이에요. 시작하면 다른 앱이 잠겨요." : "곧 공부 시간이에요. 책상 정리하고 준비해볼까요?")
                        : "곧 일정이 시작돼요.",
                    date: leadDate,
                    info: info
                )
            }

            add(
                id: "start.\(occurrence.id)",
                title: "\(plan.title) 시작",
                body: plan.isStudy ? "공부 타이머를 시작할 시간이에요. 눌러서 바로 시작하세요." : "일정을 시작할 시간이에요.",
                date: occurrence.start,
                info: info
            )
        }
    }

    private static func add(id: String, title: String, body: String, date: Date, info: [String: Any]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = info

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
