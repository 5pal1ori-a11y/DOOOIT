import Foundation

/// 친구 초대 보상: "초대에 성공한 친구 수" 하나만 세고, 배지와 테마 잠금은 모두 이 숫자에서 계산
/// - 화면·저장소와 떨어진 순수 계산이라 Linux 테스트에서 바로 확인할 수 있어요
/// - 숫자는 계정마다 따로 저장해요 (AccountStore.personalKeys에 `countKey`가 들어 있음)
/// - 숫자는 늘기만 해요. 배지·테마 열림은 숫자에서 바로 계산하므로 한 번 열리면 닫히지 않아요
///
/// 친구 기능(초대하기)은 별도 작업이에요. 거기서 "초대한 친구가 누적 1시간 이상 공부했을 때"
/// 친구 한 명당 한 번씩 `InviteRewards.recordSuccessfulInvite()`를 부르면 돼요.
/// (같은 친구로 두 번 부르지 않는 것은 친구 기능이 책임져요: 여기서는 부른 횟수만 세요)
enum InviteRewards {
    /// 초대에 성공한 친구 수를 저장하는 설정 키 (계정마다 따로)
    static let countKey = "invites.successCount"
    /// 숫자가 바뀌었다는 알림 (배지 확인 · 화면 새로고침용)
    static let changed = Notification.Name("InviteRewards.changed")

    /// 보상 단계: 친구 1명 · 3명 · 10명
    enum Tier: Int, CaseIterable {
        case one = 1, three = 3, ten = 10

        /// 필요한 친구 수
        var threshold: Int { rawValue }

        /// 이 단계의 배지 아이디 (Badges.swift의 배지와 같음)
        var badgeID: String { "invite\(rawValue)" }
    }

    /// 초대로 여는 테마
    enum RewardTheme {
        /// 선셋 (친구 3명)
        case newTheme

        var requiredInvites: Int {
            switch self {
            case .newTheme: return Tier.three.threshold
            }
        }
    }

    // MARK: 숫자

    /// 지금까지 초대에 성공한 친구 수 (저장된 값이 이상해도 0 아래로 내려가지 않음)
    static func count(defaults: UserDefaults = .standard) -> Int {
        max(0, defaults.integer(forKey: countKey))
    }

    /// 친구 한 명이 초대에 성공했을 때 부름 (친구가 누적 1시간 이상 공부했을 때). 새 숫자를 돌려줌
    @discardableResult
    static func recordSuccessfulInvite(defaults: UserDefaults = .standard) -> Int {
        let next = count(defaults: defaults) + 1
        defaults.set(next, forKey: countKey)
        NotificationCenter.default.post(name: changed, object: nil)
        return next
    }

    // MARK: 보상 계산

    /// 숫자에서 받은 배지 단계 (숫자가 늘면 늘기만 함)
    static func unlockedBadges(count: Int) -> [Tier] {
        Tier.allCases.filter { count >= $0.threshold }
    }

    static func unlockedBadges(defaults: UserDefaults = .standard) -> [Tier] {
        unlockedBadges(count: count(defaults: defaults))
    }

    static func isThemeUnlocked(_ theme: RewardTheme, count: Int) -> Bool {
        count >= theme.requiredInvites
    }

    static func isThemeUnlocked(_ theme: RewardTheme, defaults: UserDefaults = .standard) -> Bool {
        isThemeUnlocked(theme, count: count(defaults: defaults))
    }

    /// 단계까지 남은 친구 수 (이미 넘었으면 0)
    static func remaining(for tier: Tier, count: Int) -> Int {
        max(0, tier.threshold - count)
    }

    static func remaining(for tier: Tier, defaults: UserDefaults = .standard) -> Int {
        remaining(for: tier, count: count(defaults: defaults))
    }

    /// 테마가 열릴 때까지 남은 친구 수
    static func remaining(for theme: RewardTheme, count: Int) -> Int {
        max(0, theme.requiredInvites - count)
    }

    static func remaining(for theme: RewardTheme, defaults: UserDefaults = .standard) -> Int {
        remaining(for: theme, count: count(defaults: defaults))
    }
}
