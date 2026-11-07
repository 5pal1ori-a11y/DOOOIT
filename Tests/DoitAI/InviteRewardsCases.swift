import Foundation

// 친구 초대 보상: 초대 성공 수 · 배지 단계 · 테마 열림 (화면 없이 계산만)

func runInviteRewardsCases() {
    func fresh(_ name: String) -> UserDefaults {
        let suite = "InviteRewardsCases.\(name)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    // 기준: 1 · 3 · 10명
    check("초대: 단계는 1·3·10명", InviteRewards.Tier.allCases.map(\.threshold) == [1, 3, 10])
    check("초대: 선셋 테마는 3명", InviteRewards.RewardTheme.newTheme.requiredInvites == 3)

    // 처음엔 0명 · 아무것도 안 열림
    let a = fresh("a")
    check("초대: 처음엔 0명", InviteRewards.count(defaults: a) == 0)
    check("초대: 처음엔 배지 없음", InviteRewards.unlockedBadges(defaults: a).isEmpty)
    check("초대: 처음엔 테마 잠김", !InviteRewards.isThemeUnlocked(.newTheme, defaults: a))

    // 한 명씩 늘리면서 열림 확인
    var seen: [Int] = []
    for expected in 1...10 {
        let n = InviteRewards.recordSuccessfulInvite(defaults: a)
        seen.append(n)
        let tiers = InviteRewards.unlockedBadges(defaults: a).map(\.threshold)
        let wantTiers = [1, 3, 10].filter { $0 <= expected }
        check("초대: \(expected)명 배지 단계", tiers == wantTiers, "\(tiers)")
        check("초대: \(expected)명 테마 열림", InviteRewards.isThemeUnlocked(.newTheme, defaults: a) == (expected >= 3))
    }
    check("초대: 부를 때마다 1씩", seen == Array(1...10), "\(seen)")
    check("초대: 저장된 값", InviteRewards.count(defaults: a) == 10)

    // 단계 경계
    check("초대: 2명은 첫 초대만", InviteRewards.unlockedBadges(count: 2) == [.one])
    check("초대: 3명은 테마 열림", InviteRewards.isThemeUnlocked(.newTheme, count: 3) && !InviteRewards.isThemeUnlocked(.newTheme, count: 2))
    check("초대: 9명은 10명 배지 아님", InviteRewards.unlockedBadges(count: 9) == [.one, .three])
    check("초대: 10명 이상은 모두", InviteRewards.unlockedBadges(count: 25) == [.one, .three, .ten])

    // 늘기만 함: 숫자가 커지면 열린 것이 줄지 않음
    var previous = Set<Int>()
    var monotonic = true
    for n in 0...30 {
        let now = Set(InviteRewards.unlockedBadges(count: n).map(\.threshold))
        if !previous.isSubset(of: now) { monotonic = false }
        previous = now
    }
    check("초대: 배지는 줄지 않음", monotonic)
    var themeMonotonic = true
    var wasOpen = false
    for n in 0...30 {
        let open = InviteRewards.isThemeUnlocked(.newTheme, count: n)
        if wasOpen && !open { themeMonotonic = false }
        wasOpen = open
    }
    check("초대: 테마는 한 번 열리면 닫히지 않음", themeMonotonic)

    // 이상한 저장 값은 0 아래로 내려가지 않음 · 부르면 0부터 다시 셈
    let weird = fresh("weird")
    weird.set(-5, forKey: InviteRewards.countKey)
    check("초대: 음수는 0명", InviteRewards.count(defaults: weird) == 0 && InviteRewards.unlockedBadges(defaults: weird).isEmpty)
    check("초대: 음수에서도 1명부터", InviteRewards.recordSuccessfulInvite(defaults: weird) == 1)

    // 남은 친구 수
    check("초대: 0명이면 1·3·10명까지 남은 수", [InviteRewards.Tier.one, .three, .ten].map { InviteRewards.remaining(for: $0, count: 0) } == [1, 3, 10])
    check("초대: 1명이면 3명까지 2명", InviteRewards.remaining(for: .three, count: 1) == 2)
    check("초대: 넘으면 0명", InviteRewards.remaining(for: .one, count: 4) == 0 && InviteRewards.remaining(for: .three, count: 3) == 0)
    check("초대: 테마까지 남은 수", InviteRewards.remaining(for: .newTheme, count: 1) == 2 && InviteRewards.remaining(for: .newTheme, count: 7) == 0)
    let b = fresh("b")
    InviteRewards.recordSuccessfulInvite(defaults: b)
    check("초대: 저장된 값에서 남은 수", InviteRewards.remaining(for: .three, defaults: b) == 2 && InviteRewards.remaining(for: .newTheme, defaults: b) == 2)

    // 계정마다 따로: 같은 키를 계정 설정 보관·복원처럼 옮겨도 계정끼리 섞이지 않음
    check("초대: 계정별 설정 키", InviteRewards.countKey == "invites.successCount")
    let acc = fresh("accounts")
    InviteRewards.recordSuccessfulInvite(defaults: acc)
    InviteRewards.recordSuccessfulInvite(defaults: acc)
    InviteRewards.recordSuccessfulInvite(defaults: acc)
    let savedForA = acc.object(forKey: InviteRewards.countKey)          // 계정 A 보관
    acc.removeObject(forKey: InviteRewards.countKey)                    // 계정 B로 바꿈 (새 계정)
    check("초대: 새 계정은 0명 · 테마 잠김", InviteRewards.count(defaults: acc) == 0 && !InviteRewards.isThemeUnlocked(.newTheme, defaults: acc))
    InviteRewards.recordSuccessfulInvite(defaults: acc)                 // B가 한 명 초대
    let savedForB = acc.object(forKey: InviteRewards.countKey)
    acc.set(savedForA, forKey: InviteRewards.countKey)                  // 다시 A로
    check("초대: 계정 A 복원", InviteRewards.count(defaults: acc) == 3 && InviteRewards.isThemeUnlocked(.newTheme, defaults: acc))
    acc.set(savedForB, forKey: InviteRewards.countKey)
    check("초대: 계정 B는 1명", InviteRewards.count(defaults: acc) == 1 && InviteRewards.unlockedBadges(defaults: acc) == [.one])

    // 배지 목록과 이어짐: 아이디 · 기준 · 한정 표시
    let invites = BadgeBook.all.filter { $0.metric == .invites }
    check("초대 배지: 세 개", invites.count == 3, "\(invites.map(\.id))")
    check("초대 배지: 아이디가 단계와 같음", invites.map(\.id) == InviteRewards.Tier.allCases.map(\.badgeID), "\(invites.map(\.id))")
    check("초대 배지: 기준이 단계와 같음", invites.map(\.target) == InviteRewards.Tier.allCases.map(\.threshold))
    check("초대 배지: 모두 한정", invites.allSatisfy(\.limited))
    check("초대 배지: 테마를 여는 건 3명 배지 하나", BadgeBook.all.filter(\.unlocksTheme).map(\.id) == ["invite3"])
    check("초대 배지: 아이디 겹침 없음", Set(BadgeBook.all.map(\.id)).count == BadgeBook.all.count)

    // 배지 받기 · 진행 표시
    var stats = BadgeBook.Stats()
    stats.invites = 1
    let got = BadgeBook.refresh(stats: stats, unlocked: [:], now: Date(timeIntervalSince1970: 0))
    check("초대 배지: 1명이면 첫 초대만", got.new.map(\.id) == ["invite1"], "\(got.new.map(\.id))")
    let three = BadgeBook.badge("invite3")!
    check("초대 배지: 진행 1/3", three.progressText(stats) == "1 / 3명", three.progressText(stats))
    check("초대 배지: 진행률 1/3", abs(three.progress(stats) - 1.0 / 3.0) < 0.0001)
    stats.invites = 3
    let more = BadgeBook.refresh(stats: stats, unlocked: got.unlocked, now: Date(timeIntervalSince1970: 100))
    check("초대 배지: 3명이면 초대 3명 추가", more.new.map(\.id) == ["invite3"], "\(more.new.map(\.id))")
    check("초대 배지: 이미 받은 날짜는 그대로", more.unlocked["invite1"] == Date(timeIntervalSince1970: 0))
    stats.invites = 99
    let all = BadgeBook.refresh(stats: stats, unlocked: more.unlocked, now: Date(timeIntervalSince1970: 200))
    check("초대 배지: 10명이면 마지막까지", all.new.map(\.id) == ["invite10"] && all.unlocked.keys.filter { $0.hasPrefix("invite") }.count == 3)
    // 숫자가 줄어도(예: 다른 값으로 복원) 한 번 받은 날짜는 남음
    stats.invites = 0
    let after = BadgeBook.refresh(stats: stats, unlocked: all.unlocked)
    check("초대 배지: 한 번 받으면 남음", after.new.isEmpty && after.unlocked.count == all.unlocked.count)
}
