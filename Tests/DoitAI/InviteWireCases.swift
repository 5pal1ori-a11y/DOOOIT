import Foundation

// 초대 보상 연결: 초대한 친구가 누적 1시간 이상 공부하면 한 명당 한 번만 보상 숫자가 오름 (가짜 클라우드로)

private func freshDefaults(_ name: String) -> UserDefaults {
    let suite = "InviteWireCases.\(name)"
    let d = UserDefaults(suiteName: suite)!
    d.removePersistentDomain(forName: suite)
    return d
}

@MainActor
private struct Pal {
    let engine: SocialEngine
    let backend: InMemorySocialBackend
    var id: String { engine.state.profileID }

    init(_ cloud: FakeCloud, user: String, prefix: String, now: Date) {
        backend = InMemorySocialBackend(cloud: cloud, user: user)
        engine = SocialEngine(backend: backend)
        engine.now = { now }
        var n = 0
        engine.makeID = { n += 1; return "\(prefix)-\(n)" }
    }

    func start(_ nick: String) async {
        do { try await engine.setUp(nickname: nick) } catch { check("초대: \(nick) 시작", false, "\(error)") }
    }

    /// inviter의 코드를 처음 친구로 추가해서 초대받은 사람이 됨
    func join(_ inviter: Pal) async {
        do { try await engine.addFriend(code: inviter.engine.state.friendCode) } catch { check("초대: 친구 추가", false, "\(error)") }
    }

    func study(total: Int) async {
        do { try await engine.publish(totals: SocialClock.Totals(today: min(total, 3000), week: min(total, 9000), total: total), studyingSince: nil) }
        catch { check("초대: 공부 시간 올리기", false, "\(error)") }
    }
}

@MainActor
func runInviteWireCases() async {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    // 프로필 모양: totalSeconds
    do {
        var p = SocialProfile(id: "p", nickname: "a", friendCode: "X", updatedAt: now)
        p.totalSeconds = 5000
        check("초대: totalSeconds 왕복", SocialProfile(id: "p", fields: p.fields())?.totalSeconds == 5000)
        check("초대: totalSeconds는 알려진 키", SocialProfile.fieldKeys.contains("totalSeconds") && p.fields().int("totalSeconds") == 5000)
        let old = SocialProfile(id: "p", fields: ["nickname": .string("a")])
        check("초대: 예전 기록(필드 없음)은 0", old?.totalSeconds == 0)
        let wild = SocialProfile(id: "p", fields: ["nickname": .string("a"), "totalSeconds": .int(Int.max)])
        check("초대: 남이 올린 큰 값은 상한으로", wild?.totalSeconds == SocialLimits.totalSecondsMax)
        let neg = SocialProfile(id: "p", fields: ["nickname": .string("a"), "totalSeconds": .int(-9)])
        check("초대: 음수는 0", neg?.totalSeconds == 0)
        check("초대: 계정마다 따로 저장하는 키에 들어 있음", SocialKeys.all.contains(SocialKeys.countedInvites))
        check("초대: 기록 합계", SocialClock.totals(sessions: [(now, 100), (now.addingTimeInterval(-86_400 * 40), 250)], now: now).total == 350)
    }

    // 순수 판정
    do {
        func prof(_ id: String, by: String?, total: Int, hidden: Bool = false) -> SocialProfile {
            SocialProfile(id: id, nickname: id, friendCode: id, updatedAt: now, isHidden: hidden, invitedBy: by, totalSeconds: total)
        }
        let list = [prof("b", by: "me", total: 3600), prof("c", by: "me", total: 3599), prof("d", by: "other", total: 9999),
                    prof("me", by: "me", total: 9999), prof("e", by: nil, total: 9999), prof("f", by: "me", total: 9999, hidden: true),
                    prof("g", by: "me", total: 9999), prof("h", by: "me", total: 9999), prof("b", by: "me", total: 4000)]
        let out = InviteTracker.newlyQualified(invited: list, myID: "me", counted: ["h"], isBlocked: { $0 == "g" }).map(\.id)
        check("초대: 1시간 이상 · 초대받은 · 안 센 사람만 (같은 id는 한 번)", out == ["b"], "\(out)")
        check("초대: 내 id가 비면 아무도 안 셈", InviteTracker.newlyQualified(invited: list, myID: "", counted: [], isBlocked: { _ in false }).isEmpty)
    }

    // 가짜 클라우드 시나리오
    let cloud = FakeCloud()
    let a = Pal(cloud, user: "icloud-A", prefix: "A", now: now)
    let b = Pal(cloud, user: "icloud-B", prefix: "B", now: now)
    let c = Pal(cloud, user: "icloud-C", prefix: "C", now: now)
    let d = Pal(cloud, user: "icloud-D", prefix: "D", now: now)
    let e = Pal(cloud, user: "icloud-E", prefix: "E", now: now)
    let f = Pal(cloud, user: "icloud-F", prefix: "F", now: now)
    let g = Pal(cloud, user: "icloud-G", prefix: "G", now: now)
    for (pal, nick) in [(a, "하늘"), (b, "서준"), (c, "지우"), (d, "도윤"), (e, "하린"), (f, "민재"), (g, "수아")] { await pal.start(nick) }

    let defaults = freshDefaults("main")
    do {
        check("초대: 처음엔 0명", InviteRewards.count(defaults: defaults) == 0)
        check("초대: 처음엔 초대한 친구 없음", try await a.engine.syncInvites(defaults: defaults) == 0)

        await b.join(a)
        await c.join(a)
        await d.join(b)   // d는 b의 초대 (a와 상관없음)
        await e.join(a)
        await f.join(a)
        check("초대: 초대받은 쪽 프로필에 초대한 사람이 실림", cloud.profileCount == 7 && b.engine.state.invitedBy == a.id)

        // 아직 공부 안 함
        await b.study(total: 0)
        await c.study(total: 3599)
        check("초대: 1시간 전에는 안 셈", try await a.engine.syncInvites(defaults: defaults) == 0 && InviteRewards.count(defaults: defaults) == 0)

        // b가 1시간을 채움
        await b.study(total: 3600)
        check("초대: 1시간이 되면 1명", try await a.engine.syncInvites(defaults: defaults) == 1 && InviteRewards.count(defaults: defaults) == 1)
        check("초대: 센 친구가 기록됨", InviteTracker.countedIDs(defaults: defaults) == [b.id])
        check("초대: 1명이면 배지 1개", InviteRewards.unlockedBadges(defaults: defaults).map(\.threshold) == [1])

        // 두 번 세지 않음
        check("초대: 다시 확인해도 그대로", try await a.engine.syncInvites(defaults: defaults) == 0 && InviteRewards.count(defaults: defaults) == 1)
        await b.study(total: 50_000)
        check("초대: 더 공부해도 한 번만", try await a.engine.syncInvites(defaults: defaults) == 0 && InviteRewards.count(defaults: defaults) == 1)

        // 다른 사람이 초대한 친구 · 초대 안 받은 사람 · 숨김 · 차단
        await d.study(total: 99_000)           // b가 초대함: a는 셀 수 없음
        let lone = Pal(cloud, user: "icloud-L", prefix: "L", now: now)
        await lone.start("혼자")
        await lone.study(total: 99_000)        // 아무도 안 추가함: invitedBy 없음
        e.engine.setShowStatus(false)
        await e.study(total: 99_000)           // 숨김: 시간을 올리지 않음
        await f.study(total: 99_000)
        a.engine.block(profileID: f.id, nickname: "민재")   // 차단
        check("초대: 남이 초대한 사람 · 초대 안 받은 사람 · 숨김 · 차단은 안 셈",
              try await a.engine.syncInvites(defaults: defaults) == 0 && InviteRewards.count(defaults: defaults) == 1)

        // 나 자신(내 id를 invitedBy로 단 프로필)은 안 셈
        cloud.seed(profile: SocialProfile(id: a.id, nickname: "하늘", friendCode: a.engine.state.friendCode, updatedAt: now,
                                          invitedBy: a.id, totalSeconds: 99_000), creator: "icloud-A")
        check("초대: 자기 자신은 안 셈", try await a.engine.syncInvites(defaults: defaults) == 0 && InviteRewards.count(defaults: defaults) == 1)

        // 숨김을 풀면 다음에 셈
        e.engine.setShowStatus(true)
        await e.study(total: 4000)
        // c도 채움, g는 채운 뒤 프로필을 지움
        await c.study(total: 7200)
        await g.join(a)
        await g.study(total: 9000)
        try await g.backend.deleteProfile(id: g.id)
        check("초대: 숨김을 풀거나 채운 친구는 새로 셈 (지운 프로필은 안 셈)",
              try await a.engine.syncInvites(defaults: defaults) == 2 && InviteRewards.count(defaults: defaults) == 3,
              "\(InviteRewards.count(defaults: defaults))")
        check("초대: 3명이면 선셋 테마 열림", InviteRewards.isThemeUnlocked(.newTheme, defaults: defaults))
        check("초대: 센 친구 3명 기록", Set(InviteTracker.countedIDs(defaults: defaults)) == [b.id, c.id, e.id])
        check("초대: 다시 확인해도 3명", try await a.engine.syncInvites(defaults: defaults) == 0 && InviteRewards.count(defaults: defaults) == 3)

        // 친구가 나중에 프로필을 지워도 숫자는 그대로
        try await b.backend.deleteProfile(id: b.id)
        check("초대: 친구가 지워도 숫자는 그대로", try await a.engine.syncInvites(defaults: defaults) == 0 && InviteRewards.count(defaults: defaults) == 3)

        // 인터넷 오류: 던지고 숫자는 그대로
        a.backend.failNext(.network)
        do {
            _ = try await a.engine.syncInvites(defaults: defaults)
            check("초대: 네트워크 오류는 던짐", false)
        } catch {
            check("초대: 네트워크 오류는 던지고 숫자는 그대로", (error as? SocialError) == .network && InviteRewards.count(defaults: defaults) == 3)
        }
    } catch { check("초대: 시나리오", false, "\(error)") }

    // 계정마다 따로: 다른 저장소에서는 처음부터
    let other = freshDefaults("other")
    check("초대: 다른 계정 저장소는 0명 · 센 친구 없음", InviteRewards.count(defaults: other) == 0 && InviteTracker.countedIDs(defaults: other).isEmpty)

    // 켜지 않은 기기 · 숨김 상태로 올린 프로필
    do {
        let off = InMemorySocialBackend(cloud: FakeCloud(), user: "x")
        let engine = SocialEngine(backend: off)
        check("초대: 친구 기능을 안 켰으면 0", try await engine.syncInvites(defaults: freshDefaults("off")) == 0 && off.callCount == 0)
        check("초대: 보이면 총 시간을 올림", b.engine.makeProfile(totals: .init(today: 1, week: 1, total: 9999), studyingSince: nil).totalSeconds == 9999)
        b.engine.setShowStatus(false)
        let hidden = b.engine.makeProfile(totals: .init(today: 1, week: 1, total: 9999), studyingSince: nil)
        check("초대: 숨긴 프로필은 총 시간 0", hidden.totalSeconds == 0 && hidden.isHidden)
        b.engine.setShowStatus(true)
    } catch { check("초대: 꺼진 기기", false, "\(error)") }

    // 상한: 가짜 계정을 아무리 만들어도 30명까지
    do {
        let cap = FakeCloud()
        let boss = Pal(cap, user: "icloud-boss", prefix: "Z", now: now)
        await boss.start("대장")
        for i in 0..<45 {
            cap.seed(profile: SocialProfile(id: "fake-\(i)", nickname: "f\(i)", friendCode: "F\(i)", updatedAt: now,
                                            invitedBy: boss.id, totalSeconds: 3600), creator: "fake-\(i)")
        }
        let dflt = freshDefaults("cap")
        let first = try await boss.engine.syncInvites(defaults: dflt)
        let second = try await boss.engine.syncInvites(defaults: dflt)
        check("초대: 한 번에 최대 50명 중 30명까지만", first == InviteTracker.maxCounted && second == 0 && InviteRewards.count(defaults: dflt) == 30,
              "\(first) \(second) \(InviteRewards.count(defaults: dflt))")
        let before = boss.backend.callCount
        _ = try await boss.engine.syncInvites(defaults: dflt)
        check("초대: 가득 차면 서버 호출 없음", boss.backend.callCount == before)
    } catch { check("초대: 상한", false, "\(error)") }
}
