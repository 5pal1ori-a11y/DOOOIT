import DeviceActivity
import ManagedSettings

/// 공부 플랜 시작/종료 시각에 iOS가 호출하는 익스텐션.
/// 앱이 완전히 꺼져 있어도 다른 앱을 잠그고 풀어줍니다.
final class ActivityMonitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue.hasPrefix("lock.") else { return }
        store.shield.applicationCategories = .all()
        store.shield.webDomainCategories = .all()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue.hasPrefix("lock.") else { return }
        store.clearAllSettings()
    }
}
