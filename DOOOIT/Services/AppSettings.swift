import Foundation

enum SettingsKey {
    static let dailyWordGoal = "dailyWordGoal"
    static let dailyStudyGoalMinutes = "dailyStudyGoalMinutes"
    static let wordGoalDoneKey = "wordGoalDoneKey"
    static let reminderLeadMinutes = "reminderLeadMinutes"
    static let notificationsEnabled = "notificationsEnabled"
    static let liveActivityEnabled = "liveActivityEnabled"
    static let autoStartTimer = "autoStartTimer"
    static let appearance = "appearance"
    static let themeColor = "themeColor"
    static let dDayTitle = "dDayTitle"
    static let dDayDate = "dDayDate"
}

/// 뷰 밖(서비스)에서 설정값을 읽기 위한 헬퍼. 기본값은 각 화면의 @AppStorage 기본값과 같아야 함.
enum AppSettings {
    private static var defaults: UserDefaults { .standard }

    static var leadMinutes: Int {
        let v = defaults.integer(forKey: SettingsKey.reminderLeadMinutes)
        return v == 0 ? 10 : v
    }

    static var notificationsEnabled: Bool {
        defaults.object(forKey: SettingsKey.notificationsEnabled) as? Bool ?? true
    }

    static var liveActivityEnabled: Bool {
        defaults.object(forKey: SettingsKey.liveActivityEnabled) as? Bool ?? true
    }

    static var autoStartTimer: Bool {
        defaults.object(forKey: SettingsKey.autoStartTimer) as? Bool ?? true
    }
}
