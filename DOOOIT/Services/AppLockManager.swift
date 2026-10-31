import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// 공부 플랜의 "다른 앱 잠금"
/// - Screen Time(FamilyControls) 권한으로 DOOOIT을 제외한 앱을 잠급니다.
/// - 앱이 꺼져 있어도 시작/종료 시각에 잠기고 풀리도록 DeviceActivity 일정으로 등록합니다.
///   (실제 잠금/해제는 DOOOITActivityMonitor 익스텐션이 수행)
/// - 주의: com.apple.developer.family-controls 권한이 있어야 동작합니다. README의 "앱 잠금 켜기"를 참고하세요.
@MainActor
final class AppLockManager {
    static let shared = AppLockManager()

    private let store = ManagedSettingsStore()
    private let center = DeviceActivityCenter()
    private let lockUntilKey = "dooit.appLockUntil"
    static let activityPrefix = "lock."

    var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// 스크린 타임 권한 요청. 권한(entitlement)이 없는 빌드에서는 false.
    func requestAuthorization() async -> Bool {
        if isAuthorized { return true }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            print("스크린 타임 권한 요청 실패: \(error)")
        }
        return isAuthorized
    }

    var lockedUntil: Date? {
        let t = UserDefaults.standard.double(forKey: lockUntilKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    var isLocked: Bool {
        guard let lockedUntil else { return false }
        return lockedUntil > Date()
    }

    /// 지금 바로 잠금 (앱이 켜져 있을 때 공부가 시작된 경우)
    @discardableResult
    func lock(until end: Date) async -> Bool {
        guard await requestAuthorization() else { return false }
        store.shield.applicationCategories = .all()
        store.shield.webDomainCategories = .all()
        UserDefaults.standard.set(end.timeIntervalSince1970, forKey: lockUntilKey)
        return true
    }

    /// 잠금 해제 + 진행 중인 일정 감시 중단
    func endLock(planKey: String?) {
        store.clearAllSettings()
        UserDefaults.standard.removeObject(forKey: lockUntilKey)
        if let planKey {
            center.stopMonitoring([DeviceActivityName(rawValue: Self.activityPrefix + planKey)])
        }
    }

    func unlockIfExpired(now: Date = Date()) {
        if let lockedUntil, lockedUntil <= now {
            endLock(planKey: nil)
        }
    }

    /// 앞으로 7일간의 "앱 잠금" 공부 플랜을 DeviceActivity 일정으로 등록
    /// - iOS 제한: 한 번에 등록 가능한 일정 수가 제한되고, 최소 15분 이상이어야 함
    func scheduleLocks(for plans: [Plan]) {
        let existing = center.activities.filter { $0.rawValue.hasPrefix(Self.activityPrefix) }
        if !existing.isEmpty { center.stopMonitoring(existing) }
        guard isAuthorized else { return }

        let now = Date()
        var items: [PlanOccurrence] = []
        for offset in 0..<7 {
            let day = now.startOfDay.adding(days: offset)
            items += plans.occurrences(on: day).filter {
                $0.plan.isStudy && $0.plan.lockApps && !$0.plan.isAllDay && $0.end > now
            }
        }
        items.sort { $0.start < $1.start }

        let cal = Calendar.current
        let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        for occurrence in items.prefix(15) {
            let start = max(occurrence.start, now)
            guard occurrence.end.timeIntervalSince(start) >= 15 * 60 else { continue }
            let schedule = DeviceActivitySchedule(
                intervalStart: cal.dateComponents(comps, from: start),
                intervalEnd: cal.dateComponents(comps, from: occurrence.end),
                repeats: false
            )
            do {
                try center.startMonitoring(DeviceActivityName(rawValue: Self.activityPrefix + occurrence.id), during: schedule)
            } catch {
                print("앱 잠금 일정 등록 실패: \(error)")
            }
        }
    }
}
