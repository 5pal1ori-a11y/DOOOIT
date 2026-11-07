import Foundation

/// 친구가 지금 어떤지: 공부 중 · 쉬는 중 · 비공개
enum SocialPresenceState: Equatable {
    /// 공부 중 (minutes: 몇 분째, 최소 1)
    case studying(minutes: Int)
    case idle
    /// 시간을 숨기기로 한 사람 (닉네임만 보임)
    case hidden
}

enum SocialPresence {
    /// 3분 동안 갱신이 없으면 공부 중이 아닌 것으로 봄 (앱이 꺼졌거나 인터넷이 끊겼을 수 있어서)
    static let staleAfter: TimeInterval = 180

    static func state(of profile: SocialProfile, now: Date) -> SocialPresenceState {
        if profile.isHidden { return .hidden }
        guard let since = profile.studyingSince else { return .idle }
        // 오래 갱신이 없음. (친구 기기 시계가 앞서 있어 updatedAt이 미래여도 stale로 보지 않음)
        if now.timeIntervalSince(profile.updatedAt) > staleAfter { return .idle }
        let minutes = Int(max(0, now.timeIntervalSince(since)) / 60)
        return .studying(minutes: max(1, minutes))
    }

    /// 오늘 공부 시간(초). 숨긴 사람은 nil, 다른 날 기록이면 0
    static func todaySeconds(of profile: SocialProfile, todayKey: String) -> Int? {
        if profile.isHidden { return nil }
        return profile.todayKey == todayKey ? profile.todaySeconds : 0
    }

    static func weekSeconds(of profile: SocialProfile, weekKey: String) -> Int? {
        if profile.isHidden { return nil }
        return profile.weekKey == weekKey ? profile.weekSeconds : 0
    }

    /// 친구 목록 정렬: 공부 중인 사람 먼저, 그 안에서는 오늘 시간이 많은 순, 같으면 닉네임
    static func sortedForList(_ profiles: [SocialProfile], now: Date) -> [SocialProfile] {
        let today = SocialClock.dayKey(now)
        func studying(_ p: SocialProfile) -> Bool { if case .studying = state(of: p, now: now) { return true }; return false }
        return profiles.sorted { a, b in
            let sa = studying(a), sb = studying(b)
            if sa != sb { return sa }
            let ta = todaySeconds(of: a, todayKey: today) ?? -1, tb = todaySeconds(of: b, todayKey: today) ?? -1
            if ta != tb { return ta > tb }
            if a.nickname != b.nickname { return a.nickname < b.nickname }
            return a.id < b.id
        }
    }
}

// MARK: - 그룹 계산

struct GroupRankEntry: Equatable, Identifiable {
    var profile: SocialProfile
    var seconds: Int
    /// 같은 시간이면 같은 순위 (1, 1, 3)
    var rank: Int
    var id: String { profile.id }
}

enum GroupMath {
    /// 오늘 시간 순 (숨긴 사람은 맨 아래, 같으면 닉네임 → id)
    static func sortedByToday(_ profiles: [SocialProfile], now: Date) -> [SocialProfile] {
        let today = SocialClock.dayKey(now)
        return profiles.sorted { a, b in
            let ta = SocialPresence.todaySeconds(of: a, todayKey: today) ?? -1
            let tb = SocialPresence.todaySeconds(of: b, todayKey: today) ?? -1
            if ta != tb { return ta > tb }
            if a.nickname != b.nickname { return a.nickname < b.nickname }
            return a.id < b.id
        }
    }

    /// 그룹이 오늘 함께 공부한 시간 (숨긴 사람은 빠짐)
    static func totalToday(_ profiles: [SocialProfile], now: Date) -> Int {
        let today = SocialClock.dayKey(now)
        return profiles.reduce(0) { $0 + (SocialPresence.todaySeconds(of: $1, todayKey: today) ?? 0) }
    }

    static func totalWeek(_ profiles: [SocialProfile], now: Date) -> Int {
        let week = SocialClock.weekKey(now)
        return profiles.reduce(0) { $0 + (SocialPresence.weekSeconds(of: $1, weekKey: week) ?? 0) }
    }

    /// 이번 주 순위. 숨긴 사람은 순위에 넣지 않음
    static func weeklyRanking(_ profiles: [SocialProfile], now: Date) -> [GroupRankEntry] {
        let week = SocialClock.weekKey(now)
        let rows = profiles.compactMap { p -> (SocialProfile, Int)? in
            guard let s = SocialPresence.weekSeconds(of: p, weekKey: week) else { return nil }
            return (p, s)
        }.sorted { a, b in
            if a.1 != b.1 { return a.1 > b.1 }
            if a.0.nickname != b.0.nickname { return a.0.nickname < b.0.nickname }
            return a.0.id < b.0.id
        }
        var out: [GroupRankEntry] = []
        for (i, row) in rows.enumerated() {
            let rank = (i > 0 && out[i - 1].seconds == row.1) ? out[i - 1].rank : i + 1
            out.append(GroupRankEntry(profile: row.0, seconds: row.1, rank: rank))
        }
        return out
    }

    /// 지금 공부 중인 사람 수
    static func studyingCount(_ profiles: [SocialProfile], now: Date) -> Int {
        profiles.filter { if case .studying = SocialPresence.state(of: $0, now: now) { return true }; return false }.count
    }
}
