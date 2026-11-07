import Foundation

// 친구 · 그룹: 코드 · 시간 기준 · 공부 중 판정 · 그룹 계산 · 닉네임 검사 · 올리기 정책 · 규칙(가짜 클라우드로) 테스트

private func kst(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, _ s: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min; c.second = s
    return SocialClock.calendar.date(from: c) ?? Date(timeIntervalSince1970: 0)
}

private func profile(_ id: String, _ nick: String, today: Int = 0, week: Int = 0, now: Date,
                     since: Date? = nil, updated: Date? = nil, hidden: Bool = false, code: String = "") -> SocialProfile {
    SocialProfile(id: id, nickname: nick, friendCode: code, todaySeconds: today, todayKey: SocialClock.dayKey(now),
                  weekSeconds: week, weekKey: SocialClock.weekKey(now), studyingSince: since,
                  updatedAt: updated ?? now, isHidden: hidden)
}

@MainActor
private func expectError(_ name: String, _ expected: SocialError, _ body: () async throws -> Void) async {
    do {
        try await body()
        check(name, false, "오류가 나야 하는데 성공")
    } catch let e as SocialError {
        check(name, e == expected, "\(e) != \(expected)")
    } catch {
        check(name, false, "다른 오류 \(error)")
    }
}

/// 사람 한 명: 자기 기기(엔진) + 자기 iCloud 계정으로 같은 가짜 클라우드에 연결
@MainActor
private struct Person {
    let engine: SocialEngine
    let backend: InMemorySocialBackend
    var id: String { engine.state.profileID }

    init(_ cloud: FakeCloud, user: String, idPrefix: String, now: @escaping () -> Date) {
        backend = InMemorySocialBackend(cloud: cloud, user: user)
        engine = SocialEngine(backend: backend)
        engine.now = now
        var n = 0
        engine.makeID = { n += 1; return "\(idPrefix)-\(n)" }
    }
}

@MainActor
func runSocialCases() async {
    runSocialCodeCases()
    runSocialClockCases()
    runSocialPresenceCases()
    runSocialGroupMathCases()
    runSocialNicknameCases()
    runSocialMappingCases()
    runSocialPolicyCases()
    runSocialStateCases()
    await runSocialEngineCases()
    await runSocialGroupEngineCases()
}

// MARK: - 코드

@MainActor
private func runSocialCodeCases() {
    check("코드 글자는 31개", SocialCode.alphabet.count == 31, "\(SocialCode.alphabet.count)")
    for bad in "01ILO" { check("헷갈리는 글자 \(bad) 없음", !SocialCode.alphabet.contains(bad)) }
    var n = 0
    let code = SocialCode.friendCode(random: { _ in n += 1; return n })
    check("친구 코드는 8자", code.count == 8 && SocialCode.isValidFriendCode(code), code)
    check("초대 코드는 6자", SocialCode.inviteCode().count == 6 && SocialCode.isValidInviteCode(SocialCode.inviteCode()))
    for _ in 0..<200 { if !SocialCode.isValidFriendCode(SocialCode.friendCode()) { check("랜덤 친구 코드가 규칙에 맞음", false); break } }
    check("랜덤 값이 범위를 벗어나도 안전", SocialCode.generate(length: 4, random: { _ in 999 }).count == 4)
    check("정규화: 소문자 · 공백 · 줄표", SocialCode.normalize(" abcd-efgh \n") == "ABCDEFGH")
    check("표시는 가운데 줄표", SocialCode.display("ABCDEFGH") == "ABCD-EFGH" && SocialCode.display("ABC234") == "ABC-234")
    check("0 O 1 I L 들어간 코드는 무효", !SocialCode.isValidFriendCode("ABCD0EFG") && !SocialCode.isValidFriendCode("ABCDIEFG") && !SocialCode.isValidFriendCode("ABCDLEFG"))
    check("길이가 다르면 무효", !SocialCode.isValidFriendCode("ABCDEFG") && !SocialCode.isValidFriendCode("ABCDEFGHJ"))
    check("코드만 붙여 넣기", SocialCode.extractFriendCode(from: "h7k2-9pqm") == "H7K29PQM")
    check("공유 글에서 코드 찾기", SocialCode.extractFriendCode(from: "MOTI에서 같이 공부해요! 친구 코드: H7K2-9PQM") == "H7K29PQM")
    check("공유 글에서 줄표 없는 코드", SocialCode.extractFriendCode(from: "친구 코드 H7K29PQM 입력해요") == "H7K29PQM")
    check("코드가 없는 글은 nil", SocialCode.extractFriendCode(from: "안녕하세요 MOTI 같이 해요") == nil)
    check("너무 긴 영문은 코드로 안 봄", SocialCode.extractFriendCode(from: "ABCDEFGHJKMN") == nil)
    check("초대 코드 찾기", SocialCode.extractInviteCode(from: "그룹 초대 코드: abc-234") == "ABC234")
    check("빈 글은 nil", SocialCode.extractFriendCode(from: "") == nil && SocialCode.extractInviteCode(from: "   ") == nil)
}

// MARK: - 시간 기준

@MainActor
private func runSocialClockCases() {
    check("하루 키(한국 시간)", SocialClock.dayKey(kst(2026, 11, 7, 0, 0, 1)) == "2026-11-07" && SocialClock.dayKey(kst(2026, 11, 7, 23, 59, 59)) == "2026-11-07")
    // UTC 15:00 = 한국 다음날 0시
    let midnight = kst(2026, 11, 8, 0, 0, 0)
    check("한국 0시는 UTC 15시", Int(midnight.timeIntervalSince1970) % 86_400 == 15 * 3600)
    check("0시 1초 전은 전날", SocialClock.dayKey(midnight) == "2026-11-08" && SocialClock.dayKey(midnight.addingTimeInterval(-1)) == "2026-11-07")
    check("주 키: 토요일은 45주", SocialClock.weekKey(kst(2026, 11, 7)) == "2026-W45", SocialClock.weekKey(kst(2026, 11, 7)))
    check("주 키: 월요일에 바뀜", SocialClock.weekKey(kst(2026, 11, 9, 0, 0, 1)) == "2026-W46" && SocialClock.weekKey(kst(2026, 11, 8, 23, 59, 59)) == "2026-W45")
    check("주 키: 해가 바뀌어도 ISO 주", SocialClock.weekKey(kst(2027, 1, 1)) == "2026-W53" && SocialClock.weekKey(kst(2024, 12, 30)) == "2025-W01")
    let range = SocialClock.weekRange(kst(2026, 11, 7))
    check("주는 월요일 0시부터", SocialClock.dayKey(range.start) == "2026-11-02" && SocialClock.dayKey(range.end) == "2026-11-09")

    let now = kst(2026, 11, 7, 15, 0, 0)
    // 오늘 1시간, 어제 밤 11시 30분부터 1시간(자정 넘김: 오늘은 30분), 지난주 2시간
    let sessions: [(start: Date, seconds: Int)] = [
        (kst(2026, 11, 7, 9, 0, 0), 3600),
        (kst(2026, 11, 6, 23, 30, 0), 3600),
        (kst(2026, 11, 1, 10, 0, 0), 7200)
    ]
    let t = SocialClock.totals(sessions: sessions, now: now)
    check("오늘 합계는 자정 넘긴 공부를 나눠 셈", t.today == 3600 + 1800, "\(t.today)")
    check("이번 주 합계에 지난주는 빠짐", t.week == 3600 + 3600, "\(t.week)")
    check("기록이 없으면 0", SocialClock.totals(sessions: [], now: now) == SocialClock.Totals(today: 0, week: 0))
    check("0초 · 음수 기록은 무시", SocialClock.totals(sessions: [(now, 0), (now, -50)], now: now).today == 0)
    let weekStartSession = SocialClock.totals(sessions: [(kst(2026, 11, 1, 23, 0, 0), 7200)], now: now)
    check("일요일 밤 → 월요일로 넘어간 공부는 이번 주에 한 시간", weekStartSession.week == 3600, "\(weekStartSession.week)")
    let huge = SocialClock.totals(sessions: [(kst(2026, 11, 7, 0, 0, 0), 10_000_000)], now: now)
    check("하루 합계는 24시간 넘지 않음", huge.today <= 86_400)
}

// MARK: - 공부 중 판정

@MainActor
private func runSocialPresenceCases() {
    let now = kst(2026, 11, 7, 15, 0, 0)
    let fresh = profile("a", "하늘", today: 3600, now: now, since: now.addingTimeInterval(-42 * 60), updated: now.addingTimeInterval(-30))
    check("최근 소식 + 시작 시각 = 공부 중 42분째", SocialPresence.state(of: fresh, now: now) == .studying(minutes: 42), "\(SocialPresence.state(of: fresh, now: now))")
    let edge = profile("a", "하늘", now: now, since: now.addingTimeInterval(-600), updated: now.addingTimeInterval(-180))
    check("정확히 3분 전 소식까지는 공부 중", SocialPresence.state(of: edge, now: now) == .studying(minutes: 10))
    let stale = profile("a", "하늘", now: now, since: now.addingTimeInterval(-600), updated: now.addingTimeInterval(-181))
    check("3분 넘게 소식이 없으면 쉬는 중", SocialPresence.state(of: stale, now: now) == .idle)
    let none = profile("a", "하늘", now: now, since: nil, updated: now)
    check("시작 시각이 없으면 쉬는 중", SocialPresence.state(of: none, now: now) == .idle)
    let justStarted = profile("a", "하늘", now: now, since: now.addingTimeInterval(-5), updated: now)
    check("방금 시작해도 최소 1분째", SocialPresence.state(of: justStarted, now: now) == .studying(minutes: 1))
    let future = profile("a", "하늘", now: now, since: now.addingTimeInterval(120), updated: now)
    check("시작 시각이 미래여도 1분째 (시계가 어긋난 경우)", SocialPresence.state(of: future, now: now) == .studying(minutes: 1))
    let hidden = profile("a", "하늘", today: 5000, now: now, since: now.addingTimeInterval(-600), updated: now, hidden: true)
    check("숨긴 사람은 비공개", SocialPresence.state(of: hidden, now: now) == .hidden)
    check("숨긴 사람의 시간은 nil", SocialPresence.todaySeconds(of: hidden, todayKey: SocialClock.dayKey(now)) == nil && SocialPresence.weekSeconds(of: hidden, weekKey: SocialClock.weekKey(now)) == nil)
    check("오늘 시간", SocialPresence.todaySeconds(of: fresh, todayKey: SocialClock.dayKey(now)) == 3600)
    check("다른 날 기록은 오늘 0", SocialPresence.todaySeconds(of: fresh, todayKey: "2026-11-08") == 0)

    let ps = [
        profile("1", "가", today: 100, now: now),
        profile("2", "나", today: 900, now: now),
        profile("3", "다", today: 50, now: now, since: now.addingTimeInterval(-300), updated: now),
        profile("4", "라", today: 0, now: now, hidden: true)
    ]
    let order = SocialPresence.sortedForList(ps, now: now).map(\.id)
    check("친구 정렬: 공부 중 → 오늘 시간 순 → 숨김은 아래", order == ["3", "2", "1", "4"], "\(order)")
}

// MARK: - 그룹 계산

@MainActor
private func runSocialGroupMathCases() {
    let now = kst(2026, 11, 7, 15, 0, 0)
    let oldWeek = kst(2026, 10, 20)
    var stale = profile("s", "옛날", today: 9999, week: 9999, now: oldWeek)
    stale.todayKey = SocialClock.dayKey(oldWeek)
    let ps = [
        profile("a", "하늘", today: 3600, week: 20_000, now: now),
        profile("b", "서준", today: 7200, week: 20_000, now: now),
        profile("c", "지민", today: 100, week: 5000, now: now),
        profile("h", "숨김", today: 0, week: 0, now: now, hidden: true),
        stale
    ]
    let byToday = GroupMath.sortedByToday(ps, now: now).map(\.id)
    check("오늘 시간순 (숨김은 맨 아래, 옛 기록은 0)", byToday == ["b", "a", "c", "s", "h"], "\(byToday)")
    check("그룹 오늘 합계는 숨긴 사람과 옛 기록 빼고", GroupMath.totalToday(ps, now: now) == 3600 + 7200 + 100, "\(GroupMath.totalToday(ps, now: now))")
    check("그룹 이번 주 합계", GroupMath.totalWeek(ps, now: now) == 45_000)
    let ranking = GroupMath.weeklyRanking(ps, now: now)
    check("주간 순위: 같은 시간은 같은 순위", ranking.map(\.rank) == [1, 1, 3, 4], "\(ranking.map(\.rank))")
    check("주간 순위: 같으면 닉네임순, 숨긴 사람은 빠짐", ranking.map(\.profile.id) == ["b", "a", "c", "s"], "\(ranking.map(\.profile.id))")
    check("지난 주 기록은 0초로", ranking.last?.seconds == 0)
    check("빈 그룹", GroupMath.weeklyRanking([], now: now).isEmpty && GroupMath.totalToday([], now: now) == 0)
    let studying = profile("x", "공부", now: now, since: now.addingTimeInterval(-120), updated: now)
    check("공부 중인 사람 수", GroupMath.studyingCount([studying, ps[0]], now: now) == 1)
}

// MARK: - 닉네임 검사

@MainActor
private func runSocialNicknameCases() {
    check("정상 닉네임", NicknameFilter.validateNickname("공부왕") == .ok("공부왕"))
    check("앞뒤 공백 정리", NicknameFilter.validateNickname("  모티   친구 \n") == .ok("모티 친구"))
    check("빈 닉네임", NicknameFilter.validateNickname("   ") == .empty)
    check("12자까지 가능", NicknameFilter.validateNickname("가나다라마바사아자차카타") == .ok("가나다라마바사아자차카타"))
    check("13자는 너무 김", NicknameFilter.validateNickname("가나다라마바사아자차카타파") == .tooLong)
    check("그룹 이름은 20자까지", NicknameFilter.validateGroupName(String(repeating: "가", count: 20)) != .tooLong && NicknameFilter.validateGroupName(String(repeating: "가", count: 21)) == .tooLong)
    for bad in ["시발", "씨 발", "씨.발", "병신", "ㅅㅂ", "개새끼", "FUCK", "sh1t", "f u c k", "Sh!t", "지랄하네", "존나공부"] {
        check("욕설 막음: \(bad)", NicknameFilter.validateNickname(bad) == .profanity, "\(NicknameFilter.validateNickname(bad))")
    }
    for good in ["자지마", "grape", "Essex", "공부중", "수학 1등", "motivation", "classic", "하늘"] {
        check("멀쩡한 말은 통과: \(good)", { if case .ok = NicknameFilter.validateNickname(good) { return true }; return false }())
    }
    check("그룹 이름도 욕설 검사", NicknameFilter.validateGroupName("시발 스터디") == .profanity)
    check("남이 올린 욕설 닉네임은 가림", NicknameFilter.displayName("씨발") == nil && NicknameFilter.displayName("") == nil)
    check("멀쩡한 닉네임은 그대로 보임", NicknameFilter.displayName(" 하늘 ") == "하늘")
}

// MARK: - 기록 ↔ 딕셔너리

@MainActor
private func runSocialMappingCases() {
    let now = kst(2026, 11, 7, 15, 0, 0)
    let p = profile("p1", "하늘", today: 3600, week: 9000, now: now, since: now.addingTimeInterval(-60), code: "H7K29PQM")
    let f = p.fields()
    check("프로필 → 딕셔너리 → 프로필", SocialProfile(id: "p1", fields: f) == p)
    check("공부 중이 아니면 studyingSince를 안 올림", profile("p", "a", now: now).fields()["studyingSince"] == nil)
    check("숨김은 정수 1", profile("p", "a", now: now, hidden: true).fields().int("isHidden") == 1)
    check("모든 필드 이름이 알려진 키", Set(f.keys).isSubset(of: Set(SocialProfile.fieldKeys)))
    check("닉네임 없는 기록은 거부", SocialProfile(id: "x", fields: ["friendCode": .string("A")]) == nil)
    let wild = SocialProfile(id: "x", fields: ["nickname": .string("가나다라마바사아자차카타파하"), "todaySeconds": .int(99_999_999),
                                               "weekSeconds": .int(-5), "isHidden": .int(7)])
    check("남이 올린 값은 범위 안으로", wild?.nickname.count == 12 && wild?.todaySeconds == 86_400 && wild?.weekSeconds == 0 && wild?.isHidden == true,
          "\(String(describing: wild))")

    let g = StudyGroup(id: "g1", name: "수능 스터디", inviteCode: "ABC234", ownerProfileID: "p1", createdAt: now, removedProfileIDs: ["p9"])
    check("그룹 → 딕셔너리 → 그룹", StudyGroup(id: "g1", fields: g.fields()) == g)
    check("그룹 최대 인원은 20명을 넘지 않음", StudyGroup(id: "g", fields: ["name": .string("a"), "ownerProfileID": .string("o"), "maxMembers": .int(500)])?.maxMembers == 20)
    check("그룹 이름은 20자로 자름", StudyGroup(id: "g", fields: ["name": .string(String(repeating: "가", count: 40)), "ownerProfileID": .string("o")])?.name.count == 20)
    let m = GroupMember(groupID: "g1", profileID: "p1", joinedAt: now)
    check("멤버 → 딕셔너리 → 멤버", GroupMember(fields: m.fields()) == m)
    check("멤버 기록 이름은 (그룹, 프로필)로 정해짐", m.id == "gm.g1.p1" && GroupMember.recordName(groupID: "g1", profileID: "p1") == m.id)
    let r = SocialReport(id: "r1", reporterProfileID: "p1", reportedProfileID: "p2", reportedNickname: "누구", reason: .harassment, createdAt: now)
    check("신고 필드", r.fields().string("reason") == "harassment" && r.fields().string("reportedProfileID") == "p2" && r.fields().date("createdAt") == now)
    check("신고 사유 4가지", ReportReason.allCases.count == 4 && ReportReason.allCases.map(\.rawValue).contains("inappropriateName"))
    check("종류별 필드 이름", SocialRecordType.fieldKeys(SocialRecordType.group) == StudyGroup.fieldKeys && SocialRecordType.fieldKeys("x").isEmpty)
    check("MotiProfile 키가 스키마 파일과 같은 이름", SocialProfile.fieldKeys.contains("friendCode") && SocialRecordType.profile == "MotiProfile")
}

// MARK: - 올리기 정책

@MainActor
private func runSocialPolicyCases() {
    let now = kst(2026, 11, 7, 15, 0, 0)
    var p = PublishPolicy()
    check("처음 시작/멈춤은 바로", p.delay(for: .stateChange, now: now) == 0)
    check("합계만 바뀌면 20초 모아서", p.delay(for: .totalChange, now: now) == 20)
    p.recordSuccess(at: now)
    check("방금 보냈으면 5초 간격", p.delay(for: .stateChange, now: now.addingTimeInterval(1)) == 4)
    check("5초 뒤엔 바로", p.delay(for: .stateChange, now: now.addingTimeInterval(6)) == 0)
    check("공부 중 심장박동은 같은 내용이라도 보냄", p.shouldSend(PublishedSnapshot(studying: true, todaySeconds: 10, weekSeconds: 10, todayKey: "k", hidden: false, nickname: "a"),
                                                   last: PublishedSnapshot(studying: true, todaySeconds: 10, weekSeconds: 10, todayKey: "k", hidden: false, nickname: "a"), reason: .heartbeat))
    let idle = PublishedSnapshot(studying: false, todaySeconds: 10, weekSeconds: 10, todayKey: "k", hidden: false, nickname: "a")
    check("쉬는 중 같은 내용은 안 보냄", !p.shouldSend(idle, last: idle, reason: .heartbeat) && !p.shouldSend(idle, last: idle, reason: .totalChange))
    var changed = idle; changed.todaySeconds = 70
    check("합계가 바뀌면 보냄", p.shouldSend(changed, last: idle, reason: .totalChange))
    check("처음은 무조건 보냄", p.shouldSend(idle, last: nil, reason: .totalChange))
    var started = idle; started.studying = true
    check("시작하면 보냄", p.shouldSend(started, last: idle, reason: .stateChange))

    var q = PublishPolicy()
    check("인터넷 오류 첫 재시도는 30초", q.recordFailure(.network, at: now) == 30)
    check("두 번째는 60초", q.recordFailure(.network, at: now) == 60)
    check("세 번째는 120초", q.recordFailure(.network, at: now) == 120)
    for _ in 0..<10 { _ = q.recordFailure(.network, at: now) }
    check("최대 5분", q.backoff == 300)
    q.recordSuccess(at: now)
    check("성공하면 처음부터", q.failures == 0 && q.backoff == 0)
    var r = PublishPolicy()
    check("너무 자주 보냄(rateLimited)이면 알려 준 시간만큼", r.recordFailure(.rateLimited(42), at: now) == 42)
    check("그 시간 안에는 어떤 이유로도 못 보냄", r.delay(for: .stateChange, now: now.addingTimeInterval(10)) == 32 && r.delay(for: .heartbeat, now: now.addingTimeInterval(41)) == 1)
    check("시간이 지나면 보냄", r.delay(for: .stateChange, now: now.addingTimeInterval(43)) == 0)
    var s1 = PublishPolicy(), s2 = PublishPolicy(), s3 = PublishPolicy(), s4 = PublishPolicy()
    check("로그인 안 됨 · 권한 없음은 재시도 안 함", s1.recordFailure(.noAccount, at: now) == nil && s2.recordFailure(.permissionDenied, at: now) == nil)
    check("서버 오류는 재시도", s3.recordFailure(.server("x"), at: now) == 30 && s4.recordFailure(.unavailable, at: now) == 30)
}

// MARK: - 저장

@MainActor
private func runSocialStateCases() {
    var s = SocialState()
    s.enabled = true; s.profileID = "p"; s.friendCode = "H7K29PQM"; s.nickname = "하늘"
    s.friends = [FriendRef(id: "f1", nickname: "서준", addedAt: Date(timeIntervalSince1970: 100))]
    s.blocked = [BlockedRef(id: "b1", nickname: "나쁜")]
    s.groups = [JoinedGroup(id: "g1", name: "스터디", isOwner: true, joinedAt: Date(timeIntervalSince1970: 200))]
    s.pendingReports = [SocialReport(id: "r", reporterProfileID: "p", reportedProfileID: "b1", reportedNickname: "나쁜", reason: .spam, createdAt: Date(timeIntervalSince1970: 300))]
    check("상태 저장 → 읽기", SocialState.decode(s.encoded()) == s)
    check("깨진 데이터는 빈 상태", SocialState.decode(Data("not json".utf8)) == SocialState() && SocialState.decode(nil) == SocialState())
    check("친구/차단 확인", s.isFriend("f1") && !s.isFriend("zz") && s.isBlocked("b1"))
    let suite = "social.test.\(UUID().uuidString)"
    if let d = UserDefaults(suiteName: suite) {
        let store = SocialStateStore(defaults: d)
        check("처음엔 빈 상태", store.load() == SocialState())
        store.save(s)
        check("UserDefaults에 저장하고 읽음", store.load() == s)
        store.clear()
        check("지우면 빈 상태", store.load() == SocialState())
        d.removePersistentDomain(forName: suite)
    }
    check("계정마다 따로 저장하는 키에 들어감", SocialKeys.all == ["social.state"])
}

// MARK: - 친구 규칙 (가짜 클라우드)

@MainActor
private func runSocialEngineCases() async {
    var clock = kst(2026, 11, 7, 15, 0, 0)
    let cloud = FakeCloud()
    let a = Person(cloud, user: "icloud-A", idPrefix: "A", now: { clock })
    let b = Person(cloud, user: "icloud-B", idPrefix: "B", now: { clock })

    await expectError("닉네임이 비면 시작 못 함", .nicknameEmpty) { try await a.engine.setUp(nickname: "  ") }
    await expectError("욕설 닉네임은 시작 못 함", .nicknameRejected) { try await a.engine.setUp(nickname: "씨발") }
    await expectError("긴 닉네임은 시작 못 함", .nicknameTooLong) { try await a.engine.setUp(nickname: "가나다라마바사아자차카타파") }
    check("실패하면 프로필이 안 만들어짐", cloud.profileCount == 0 && !a.engine.state.enabled)
    await expectError("시작 전에 친구 추가는 못 함", .notSetUp) { try await a.engine.addFriend(code: "H7K29PQM") }

    do {
        try await a.engine.setUp(nickname: " 하늘 ")
        try await b.engine.setUp(nickname: "서준")
    } catch { check("시작", false, "\(error)") }
    check("시작하면 프로필이 올라감", cloud.profileCount == 2 && a.engine.state.enabled && a.engine.state.nickname == "하늘")
    check("친구 코드는 8자 유효", SocialCode.isValidFriendCode(a.engine.state.friendCode) && a.engine.state.friendCode != b.engine.state.friendCode)
    check("프로필 아이디는 기기에서 정한 값", a.id == "A-1" && b.id == "B-1")
    check("계정 표시가 저장됨", a.engine.state.iCloudOwner == "icloud-A")

    // 친구 추가
    await expectError("잘못된 코드", .invalidCode) { try await a.engine.addFriend(code: "12") }
    await expectError("내 코드는 못 추가", .selfCode) { try await a.engine.addFriend(code: a.engine.state.friendCode) }
    await expectError("없는 코드", .codeNotFound) { try await a.engine.addFriend(code: "ZZZZ-ZZZZ") }
    do {
        let ref = try await a.engine.addFriend(code: "친구 코드: \(SocialCode.display(b.engine.state.friendCode))")
        check("공유 글로 친구 추가", ref.id == b.id && ref.nickname == "서준" && a.engine.state.friends.count == 1)
    } catch { check("친구 추가", false, "\(error)") }
    await expectError("이미 친구", .alreadyFriend) { try await a.engine.addFriend(code: b.engine.state.friendCode) }

    // 공부 중 올리기 + 친구가 봄
    do {
        let since = clock.addingTimeInterval(-42 * 60)
        try await b.engine.publish(totals: SocialClock.Totals(today: 4000, week: 12000), studyingSince: since)
        var rows = try await a.engine.refreshFriends()
        var p = rows.first?.profile
        check("친구가 공부 중인 모습을 봄", p.map { SocialPresence.state(of: $0, now: clock) } == .studying(minutes: 42), "\(String(describing: p))")
        check("오늘 시간과 주간 시간", p?.todaySeconds == 4000 && p?.weekSeconds == 12000 && p?.todayKey == "2026-11-07" && p?.weekKey == "2026-W45")
        clock = clock.addingTimeInterval(200)
        rows = try await a.engine.refreshFriends()
        p = rows.first?.profile
        check("3분 넘게 갱신이 없으면 쉬는 중으로 보임", p.map { SocialPresence.state(of: $0, now: clock) } == .idle)
        clock = clock.addingTimeInterval(-200)

        // 숨기기
        b.engine.setShowStatus(false)
        try await b.engine.publish(totals: SocialClock.Totals(today: 4000, week: 12000), studyingSince: since)
        rows = try await a.engine.refreshFriends()
        p = rows.first?.profile
        check("숨기면 시간 · 공부 중이 아예 올라가지 않음", p?.isHidden == true && p?.todaySeconds == 0 && p?.weekSeconds == 0 && p?.studyingSince == nil,
              "\(String(describing: p))")
        check("숨긴 사람은 비공개로 보임", p.map { SocialPresence.state(of: $0, now: clock) } == .hidden)
        b.engine.setShowStatus(true)
    } catch { check("공부 중 올리기", false, "\(error)") }

    // 남의 프로필은 못 바꿈 (보안 규칙)
    do {
        let forged = profile(b.id, "해킹", now: clock, code: "ZZZZZZZZ")
        try await a.backend.saveProfile(forged)
        check("남의 프로필은 못 바꿈", false, "저장됨")
    } catch { check("남의 프로필은 못 바꿈", (error as? SocialError) == .permissionDenied, "\(error)") }

    // 코드 다시 만들기
    do {
        let old = b.engine.state.friendCode
        try await b.engine.regenerateFriendCode()
        check("새 코드는 예전 코드와 다름", b.engine.state.friendCode != old && SocialCode.isValidFriendCode(b.engine.state.friendCode))
        let found = try await a.backend.findProfile(friendCode: old)
        check("예전 코드로는 더 이상 못 찾음", found == nil)
        let rows = try await a.engine.refreshFriends()
        check("이미 친구가 된 사람은 그대로 보임", rows.first?.profile?.friendCode == b.engine.state.friendCode)
    } catch { check("코드 다시 만들기", false, "\(error)") }

    // 닉네임 바꾸기
    do {
        try await b.engine.setNickname("서준2")
        let rows = try await a.engine.refreshFriends()
        check("닉네임을 바꾸면 친구에게도 바뀜 + 저장해 둠", rows.first?.profile?.nickname == "서준2" && a.engine.state.friends.first?.nickname == "서준2")
    } catch { check("닉네임 바꾸기", false, "\(error)") }
    await expectError("닉네임 바꾸기도 욕설 검사", .nicknameRejected) { try await b.engine.setNickname("병신") }
    check("실패하면 닉네임 그대로", b.engine.state.nickname == "서준2")

    // 오류: 인터넷 없음
    a.backend.failNext(.network)
    await expectError("인터넷 오류는 그대로 알림", .network) { _ = try await a.engine.refreshFriends() }
    a.backend.failNext(.rateLimited(30))
    await expectError("너무 자주 보냄 오류는 시간을 담아 알림", .rateLimited(30)) { _ = try await a.engine.refreshFriends() }

    // 친구 삭제 · 차단 · 신고
    do {
        a.engine.removeFriend(b.id)
        check("친구 삭제", a.engine.state.friends.isEmpty)
        let again = try await a.engine.addFriend(code: b.engine.state.friendCode)
        check("삭제 뒤 다시 추가", again.id == b.id)

        let cBackend = Person(cloud, user: "icloud-C", idPrefix: "C", now: { clock })
        try await cBackend.engine.setUp(nickname: "나쁜친구")
        _ = try await a.engine.addFriend(code: cBackend.engine.state.friendCode)
        await a.engine.report(profileID: cBackend.id, nickname: "나쁜친구", reason: .harassment)
        check("신고하면 기록이 올라가고 친구에서 빠지고 차단됨", cloud.reportCount == 1 && a.engine.state.isBlocked(cBackend.id) && !a.engine.state.isFriend(cBackend.id))
        let rep = cloud.reports.first
        check("신고 내용", rep?.reporterProfileID == a.id && rep?.reportedProfileID == cBackend.id && rep?.reason == .harassment && rep?.reportedNickname == "나쁜친구")
        await expectError("차단한 사람은 코드로도 못 추가", .blockedUser) { try await a.engine.addFriend(code: cBackend.engine.state.friendCode) }
        a.engine.unblock(cBackend.id)
        check("차단 풀기", !a.engine.state.isBlocked(cBackend.id))

        a.backend.failNext(.network)
        await a.engine.report(profileID: cBackend.id, nickname: "나쁜친구", reason: .spam)
        check("인터넷이 없으면 신고는 나중에 보냄 (차단은 바로)", cloud.reportCount == 1 && a.engine.state.pendingReports.count == 1 && a.engine.state.isBlocked(cBackend.id))
        await a.engine.flushPendingReports()
        check("연결되면 못 보낸 신고를 보냄", cloud.reportCount == 2 && a.engine.state.pendingReports.isEmpty)
        let rows = try await a.engine.refreshFriends()
        check("차단한 사람은 친구 목록에서 안 보임", !rows.contains { $0.id == cBackend.id })
    } catch { check("삭제 · 차단 · 신고", false, "\(error)") }

    // 사라진 프로필
    do {
        try await b.backend.deleteProfile(id: b.id)
        let rows = try await a.engine.refreshFriends()
        check("상대가 프로필을 지우면 닉네임만 남은 줄", rows.first?.profile == nil && rows.first?.ref.nickname == "서준2")
    } catch { check("사라진 프로필", false, "\(error)") }

    // 친구 수 제한
    do {
        let capped = Person(FakeCloud(), user: "icloud-X", idPrefix: "X", now: { clock })
        try await capped.engine.setUp(nickname: "많은")
        let many = (0..<SocialLimits.friendMax).map { FriendRef(id: "f\($0)", nickname: "f", addedAt: clock) }
        var st = capped.engine.state; st.friends = many
        capped.engine.replaceState(st)
        await expectError("친구는 최대 50명", .friendLimit) { try await capped.engine.addFriend(code: "ABCD-EFGH") }
    } catch { check("친구 수 제한", false, "\(error)") }

    // 계정이 바뀌면 처음부터
    do {
        let shared = FakeCloud()
        let first = InMemorySocialBackend(cloud: shared, user: "icloud-1")
        let engine = SocialEngine(backend: first)
        try await engine.setUp(nickname: "원래")
        check("계정 1로 시작", engine.state.enabled && engine.state.iCloudOwner == "icloud-1")
        let saved = engine.state
        let second = InMemorySocialBackend(cloud: shared, user: "icloud-2")
        let engine2 = SocialEngine(backend: second, state: saved)
        try await engine2.bindAccount()
        check("다른 iCloud 계정이면 예전 프로필을 이어 쓰지 않음", !engine2.state.enabled && engine2.state.profileID.isEmpty && engine2.state.iCloudOwner == "icloud-2")
    } catch { check("계정 바뀜", false, "\(error)") }

    // 로그인 안 됨
    do {
        let off = InMemorySocialBackend(cloud: FakeCloud(), user: "u", status: .noAccount)
        let engine = SocialEngine(backend: off)
        await expectError("iCloud 로그인이 없으면 시작 못 함", .noAccount) { try await engine.setUp(nickname: "하늘") }
        check("상태 확인", await off.accountStatus() == .noAccount)
    }
}

// MARK: - 그룹 규칙 (가짜 클라우드)

@MainActor
private func runSocialGroupEngineCases() async {
    let clock = kst(2026, 11, 7, 15, 0, 0)
    let cloud = FakeCloud()
    let a = Person(cloud, user: "icloud-A", idPrefix: "A", now: { clock })
    let b = Person(cloud, user: "icloud-B", idPrefix: "B", now: { clock })
    let c = Person(cloud, user: "icloud-C", idPrefix: "C", now: { clock })
    do {
        try await a.engine.setUp(nickname: "하늘")
        try await b.engine.setUp(nickname: "서준")
        try await c.engine.setUp(nickname: "지민")
        try await a.engine.publish(totals: SocialClock.Totals(today: 3600, week: 20000), studyingSince: nil)
        try await b.engine.publish(totals: SocialClock.Totals(today: 7200, week: 10000), studyingSince: clock.addingTimeInterval(-600))
        try await c.engine.publish(totals: SocialClock.Totals(today: 100, week: 500), studyingSince: nil)
    } catch { check("그룹 테스트 준비", false, "\(error)"); return }

    await expectError("그룹 이름이 비면 못 만듦", .groupNameInvalid) { try await a.engine.createGroup(name: " ") }
    await expectError("그룹 이름이 21자면 못 만듦", .groupNameInvalid) { try await a.engine.createGroup(name: String(repeating: "가", count: 21)) }
    await expectError("그룹 이름도 욕설 검사", .groupNameInvalid) { try await a.engine.createGroup(name: "씨발 모임") }

    var group: StudyGroup?
    do {
        group = try await a.engine.createGroup(name: "수능 스터디")
        check("그룹 만들기", group?.name == "수능 스터디" && group?.ownerProfileID == a.id && group?.maxMembers == 20 && SocialCode.isValidInviteCode(group?.inviteCode ?? ""))
        check("만든 사람이 멤버로 들어감", cloud.memberCount == 1 && a.engine.state.groups.first?.isOwner == true)
    } catch { check("그룹 만들기", false, "\(error)"); return }
    guard let group else { return }

    await expectError("잘못된 초대 코드", .invalidCode) { try await b.engine.joinGroup(code: "xx") }
    await expectError("없는 초대 코드", .codeNotFound) { try await b.engine.joinGroup(code: "ZZZ-ZZZ") }
    do {
        let joined = try await b.engine.joinGroup(code: "초대 코드: \(SocialCode.display(group.inviteCode))")
        check("초대 코드로 참여", joined.id == group.id && b.engine.state.groups.first?.isOwner == false && cloud.memberCount == 2)
        _ = try await c.engine.joinGroup(code: group.inviteCode.lowercased())
        check("소문자로 쳐도 참여", cloud.memberCount == 3)
    } catch { check("그룹 참여", false, "\(error)") }
    await expectError("이미 참여한 그룹", .alreadyMember) { try await b.engine.joinGroup(code: group.inviteCode) }

    // 그룹 화면
    do {
        let detail = try await a.engine.loadGroup(group.id)
        check("멤버 3명", detail.members.count == 3 && detail.iAmOwner)
        let sorted = GroupMath.sortedByToday(detail.members.map(\.profile), now: clock).map(\.nickname)
        check("오늘 시간순: 서준 → 하늘 → 지민", sorted == ["서준", "하늘", "지민"], "\(sorted)")
        check("그룹 오늘 합계", GroupMath.totalToday(detail.members.map(\.profile), now: clock) == 10_900)
        let rank = GroupMath.weeklyRanking(detail.members.map(\.profile), now: clock)
        check("주간 순위", rank.map(\.profile.nickname) == ["하늘", "서준", "지민"] && rank.map(\.rank) == [1, 2, 3])
        check("공부 중인 사람 표시", detail.members.first { $0.profile.id == b.id }.map { SocialPresence.state(of: $0.profile, now: clock) } == .studying(minutes: 10))
        check("내 줄 · 만든 사람 표시", detail.members.first { $0.profile.id == a.id }?.isMe == true && detail.members.first { $0.profile.id == a.id }?.isOwner == true)
    } catch { check("그룹 화면", false, "\(error)") }

    // 차단한 사람은 그룹에서도 안 보임
    do {
        c.engine.block(profileID: b.id, nickname: "서준")
        let detail = try await c.engine.loadGroup(group.id)
        check("차단한 사람은 그룹 목록에서 빠짐", !detail.members.contains { $0.profile.id == b.id } && detail.members.count == 2)
        c.engine.unblock(b.id)
    } catch { check("그룹 차단", false, "\(error)") }

    // 만든 사람만 내보낼 수 있음
    await expectError("멤버는 남을 못 내보냄", .notOwner) { try await b.engine.removeMember(groupID: group.id, profileID: c.id) }
    await expectError("만든 사람은 자신을 내보낼 수 없음", .notOwner) { try await a.engine.removeMember(groupID: group.id, profileID: a.id) }
    do {
        try await a.engine.removeMember(groupID: group.id, profileID: c.id)
        let detail = try await a.engine.loadGroup(group.id)
        check("내보내면 목록에서 빠짐", detail.members.count == 2 && !detail.members.contains { $0.profile.id == c.id })
        await expectError("내보내진 사람이 열면 알려 줌", .removedFromGroup) { _ = try await c.engine.loadGroup(group.id) }
        check("내보내진 사람의 기기는 스스로 그룹을 정리", c.engine.state.groups.isEmpty && cloud.memberCount == 2)
        await expectError("내보내진 사람은 다시 못 들어옴", .removedFromGroup) { try await c.engine.joinGroup(code: group.inviteCode) }
    } catch { check("멤버 내보내기", false, "\(error)") }

    // 나가기
    do {
        try await b.engine.leaveGroup(group.id)
        check("나가면 멤버 기록이 지워짐", b.engine.state.groups.isEmpty && cloud.memberCount == 1)
        _ = try await b.engine.joinGroup(code: group.inviteCode)
        check("나갔다 다시 들어올 수 있음", cloud.memberCount == 2)
    } catch { check("그룹 나가기", false, "\(error)") }
    await expectError("멤버는 그룹을 못 지움", .notOwner) { try await b.engine.deleteGroup(group.id) }

    // 정원
    do {
        let small = StudyGroup(id: "small", name: "작은 방", inviteCode: "SMAKE2", ownerProfileID: a.id, maxMembers: 1, createdAt: clock)
        cloud.seed(group: small, creator: "icloud-A")
        cloud.seed(member: GroupMember(groupID: "small", profileID: a.id, joinedAt: clock), creator: "icloud-A")
        let membersBefore = cloud.memberCount
        await expectError("정원이 차면 못 들어감", .groupFull) { try await b.engine.joinGroup(code: "SMAKE2") }
        check("정원 초과 시 멤버 기록이 안 남음", cloud.memberCount == membersBefore)
        check("정원 초과 시 이 기기 그룹 목록도 그대로", !b.engine.state.groups.contains { $0.id == "small" })
        let twenty = StudyGroup(id: "g20", name: "스무 명", inviteCode: "TWENTY", ownerProfileID: "owner", createdAt: clock)
        cloud.seed(group: twenty, creator: "owner-icloud")
        for i in 0..<20 { cloud.seed(member: GroupMember(groupID: "g20", profileID: "m\(i)", joinedAt: clock), creator: "m\(i)") }
        await expectError("20명이 넘으면 못 들어감", .groupFull) { try await c.engine.joinGroup(code: "TWENTY") }
    }

    // 그룹 수 제한
    do {
        let capped = Person(FakeCloud(), user: "icloud-Y", idPrefix: "Y", now: { clock })
        try await capped.engine.setUp(nickname: "많은")
        for i in 0..<SocialLimits.joinedGroupMax { _ = try await capped.engine.createGroup(name: "그룹\(i)") }
        await expectError("그룹은 최대 5개", .groupLimit) { try await capped.engine.createGroup(name: "여섯째") }
    } catch { check("그룹 수 제한", false, "\(error)") }

    // 만든 사람이 지움 → 다른 멤버 기기는 스스로 정리
    do {
        try await a.engine.deleteGroup(group.id)
        check("그룹 삭제", a.engine.state.groups.isEmpty)
        await expectError("지워진 그룹을 열면 알려 줌", .groupGone) { _ = try await b.engine.loadGroup(group.id) }
        let leftover = try await b.backend.fetchMembers(groupID: group.id)
        check("멤버 기기도 정리되고 멤버 기록이 남지 않음", b.engine.state.groups.isEmpty && !leftover.contains { $0.profileID == b.id })
    } catch { check("그룹 삭제", false, "\(error)") }

    // 내 정보 지우기
    do {
        let g1 = try await a.engine.createGroup(name: "내 그룹")
        _ = try await b.engine.joinGroup(code: g1.inviteCode)
        let g2 = try await b.engine.createGroup(name: "서준 그룹")
        _ = try await a.engine.joinGroup(code: g2.inviteCode)
        let before = (cloud.profileCount, cloud.groupCount, cloud.memberCount)
        a.backend.failNext(.network)
        await expectError("지우는 중 실패하면 그대로 두고 알림", .network) { try await a.engine.deleteEverything() }
        check("실패하면 기기 상태가 남아 있어 다시 할 수 있음", a.engine.state.enabled && a.engine.state.groups.count == 2 && cloud.profileCount == before.0)
        try await a.engine.deleteEverything()
        let aGroups = cloud.groupCount
        check("내 프로필이 지워짐", (try await b.backend.fetchProfiles(ids: [a.id])).isEmpty)
        check("내가 만든 그룹이 지워짐", aGroups == before.1 - 2, "\(aGroups) vs \(before.1)")
        let leftover = try await b.backend.fetchMemberships(profileID: a.id)
        check("내 멤버 기록이 지워짐", leftover.isEmpty)
        check("기기 상태가 비워짐", !a.engine.state.enabled && a.engine.state.friends.isEmpty && a.engine.state.groups.isEmpty && a.engine.state.profileID.isEmpty)
        let bProfiles = try await b.backend.fetchProfiles(ids: [b.id])
        let bGroup = try await b.backend.fetchGroup(id: g2.id)
        check("남의 프로필과 그룹은 그대로", bProfiles.count == 1 && bGroup != nil)
    } catch { check("내 정보 지우기", false, "\(error)") }
}
