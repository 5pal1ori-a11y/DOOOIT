import Foundation

/// 초대 보상 연결: "내가 초대한 친구가 누적 1시간 이상 공부했는지"를 확인해서
/// 새로 조건을 채운 친구 한 명당 한 번씩 InviteRewards.recordSuccessfulInvite()를 부름
/// - 초대한 친구 = 프로필에 invitedBy가 내 프로필 id로 적힌 사람 (그 사람이 처음 추가한 친구가 나일 때)
/// - 센 친구는 계정마다 따로 기기에 적어 둠 (같은 친구를 두 번 세지 않음. 친구가 나중에 프로필을 지워도 숫자는 그대로)
enum InviteTracker {
    /// 이만큼(초) 공부해야 초대 성공
    static let qualifyingSeconds = 3600
    /// 한 계정에서 셀 수 있는 최대 친구 수 (가짜 계정을 잔뜩 만들어도 여기까지)
    static let maxCounted = 30

    static func countedIDs(defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: SocialKeys.countedInvites) ?? []
    }

    /// 이번에 새로 조건을 채운 친구들 (나 · 차단한 사람 · 숨긴 사람 · 이미 센 사람 · 1시간 미만은 뺌. 같은 id는 한 번만)
    static func newlyQualified(invited: [SocialProfile], myID: String, counted: Set<String>,
                               isBlocked: (String) -> Bool) -> [SocialProfile] {
        var seen = Set<String>()
        var out: [SocialProfile] = []
        for p in invited.sorted(by: { $0.id < $1.id }) {
            guard !myID.isEmpty, p.id != myID, p.invitedBy == myID else { continue }
            guard !p.isHidden, !isBlocked(p.id), !counted.contains(p.id) else { continue }
            guard p.totalSeconds >= qualifyingSeconds else { continue }
            guard seen.insert(p.id).inserted else { continue }
            out.append(p)
        }
        return out
    }
}

extension SocialEngine {
    /// 초대한 친구를 확인하고 새로 조건을 채운 친구마다 보상 숫자를 올림. 새로 센 친구 수를 돌려줌
    /// (인터넷 · 서버 오류는 던짐: 호출한 쪽은 무시해도 됨. 다음 새로고침 때 다시 확인)
    @discardableResult
    func syncInvites(defaults: UserDefaults = .standard) async throws -> Int {
        guard state.enabled, !state.profileID.isEmpty else { return 0 }
        var counted = InviteTracker.countedIDs(defaults: defaults)
        guard counted.count < InviteTracker.maxCounted else { return 0 }
        let myID = state.profileID
        let invited = try await backend.fetchInvited(by: myID)
        let blocked = state
        let fresh = InviteTracker.newlyQualified(invited: invited, myID: myID, counted: Set(counted),
                                                 isBlocked: { blocked.isBlocked($0) })
        var added = 0
        for p in fresh {
            guard counted.count < InviteTracker.maxCounted else { break }
            // 먼저 적어 두고 올림: 중간에 앱이 꺼져도 같은 친구를 두 번 세지 않음
            counted.append(p.id)
            defaults.set(counted, forKey: SocialKeys.countedInvites)
            InviteRewards.recordSuccessfulInvite(defaults: defaults)
            added += 1
        }
        return added
    }
}
