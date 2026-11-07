import Foundation

// 친구 · 그룹 규칙 (Foundation만 씀). 화면은 이 위에서 SocialBackend(진짜 CloudKit 또는 가짜)로 일해요.

struct FriendRow: Equatable, Identifiable {
    var ref: FriendRef
    /// nil이면 프로필을 찾지 못함 (상대가 지웠거나 아직 못 불러옴)
    var profile: SocialProfile?
    var id: String { ref.id }
}

struct GroupMemberRow: Equatable, Identifiable {
    var profile: SocialProfile
    var joinedAt: Date
    var isMe: Bool
    var isOwner: Bool
    var id: String { profile.id }
}

struct GroupDetail: Equatable {
    var group: StudyGroup
    var members: [GroupMemberRow]
    var iAmOwner: Bool
}

@MainActor
final class SocialEngine {
    private(set) var state: SocialState
    let backend: SocialBackend
    var now: () -> Date = { Date() }
    var randomInt: (Int) -> Int = { Int.random(in: 0..<$0) }
    var makeID: () -> String = { UUID().uuidString }
    /// 상태가 바뀔 때마다 (저장하려고)
    var onChange: ((SocialState) -> Void)?
    /// 마지막으로 올린 프로필 (닉네임 · 코드만 바꿀 때 시간은 그대로 다시 올림)
    private(set) var lastProfile: SocialProfile?

    init(backend: SocialBackend, state: SocialState = SocialState()) {
        self.backend = backend
        self.state = state
    }

    func replaceState(_ new: SocialState) {
        state = new
        lastProfile = nil
    }

    private func mutate(_ body: (inout SocialState) -> Void) {
        body(&state)
        onChange?(state)
    }

    // MARK: 시작 · 계정

    /// iCloud 계정이 바뀌었으면 (다른 사람의 프로필을 이어 쓰지 않게) 처음부터
    func bindAccount() async throws {
        let token = try await backend.accountToken()
        if state.iCloudOwner == token { return }
        if state.iCloudOwner.isEmpty {
            // 아직 계정 표시가 없음: 이 계정 것으로 인정
            mutate { $0.iCloudOwner = token }
        } else {
            lastProfile = nil
            mutate { $0 = SocialState(); $0.iCloudOwner = token }
        }
    }

    /// 처음 시작: 닉네임을 정하고 프로필(친구 코드 포함)을 만듦
    func setUp(nickname raw: String, totals: SocialClock.Totals = .init(today: 0, week: 0)) async throws {
        let nickname = try Self.checkedNickname(raw)
        try await bindAccount()
        var profileID = state.profileID
        if profileID.isEmpty { profileID = makeID() }
        var code = state.friendCode
        if !SocialCode.isValidFriendCode(code) { code = try await uniqueFriendCode() }
        mutate {
            $0.profileID = profileID
            $0.friendCode = code
            $0.nickname = nickname
        }
        try await publish(totals: totals, studyingSince: nil)
        mutate { $0.enabled = true }
    }

    static func checkedNickname(_ raw: String) throws -> String {
        switch NicknameFilter.validateNickname(raw) {
        case .ok(let text): return text
        case .empty: throw SocialError.nicknameEmpty
        case .tooLong: throw SocialError.nicknameTooLong
        case .profanity: throw SocialError.nicknameRejected
        }
    }

    private func requireSetUp() throws {
        guard state.enabled, !state.profileID.isEmpty else { throw SocialError.notSetUp }
    }

    private func uniqueFriendCode() async throws -> String {
        for _ in 0..<8 {
            let code = SocialCode.friendCode(random: randomInt)
            if try await backend.findProfile(friendCode: code) == nil { return code }
        }
        throw SocialError.server("code")
    }

    private func uniqueInviteCode() async throws -> String {
        for _ in 0..<8 {
            let code = SocialCode.inviteCode(random: randomInt)
            if try await backend.findGroup(inviteCode: code) == nil { return code }
        }
        throw SocialError.server("code")
    }

    // MARK: 내 프로필 올리기

    func makeProfile(totals: SocialClock.Totals, studyingSince: Date?) -> SocialProfile {
        let at = now()
        if state.showStatus {
            return SocialProfile(id: state.profileID, nickname: state.nickname, friendCode: state.friendCode,
                                 todaySeconds: totals.today, todayKey: SocialClock.dayKey(at),
                                 weekSeconds: totals.week, weekKey: SocialClock.weekKey(at),
                                 studyingSince: studyingSince, updatedAt: at, isHidden: false)
        }
        // 숨기기: 시간 · 공부 중 표시는 아예 올리지 않음
        return SocialProfile(id: state.profileID, nickname: state.nickname, friendCode: state.friendCode,
                             todaySeconds: 0, todayKey: SocialClock.dayKey(at), weekSeconds: 0, weekKey: SocialClock.weekKey(at),
                             studyingSince: nil, updatedAt: at, isHidden: true)
    }

    @discardableResult
    func publish(totals: SocialClock.Totals, studyingSince: Date?) async throws -> SocialProfile {
        try requireSetUpOrSettingUp()
        let profile = makeProfile(totals: totals, studyingSince: studyingSince)
        try await backend.saveProfile(profile)
        lastProfile = profile
        return profile
    }

    private func requireSetUpOrSettingUp() throws {
        guard !state.profileID.isEmpty else { throw SocialError.notSetUp }
    }

    func setShowStatus(_ on: Bool) {
        mutate { $0.showStatus = on }
    }

    func setNickname(_ raw: String) async throws {
        try requireSetUp()
        let nickname = try Self.checkedNickname(raw)
        let previous = state.nickname
        mutate { $0.nickname = nickname }
        do {
            try await republishLast()
        } catch {
            mutate { $0.nickname = previous }
            throw error
        }
    }

    /// "코드 다시 만들기": 새 코드로 바꿈 (예전 코드로는 더 이상 못 찾음. 이미 친구가 된 사람은 그대로 볼 수 있음)
    func regenerateFriendCode() async throws {
        try requireSetUp()
        let old = state.friendCode
        let code = try await uniqueFriendCode()
        mutate { $0.friendCode = code }
        do {
            try await republishLast()
        } catch {
            mutate { $0.friendCode = old }
            throw error
        }
    }

    private func republishLast() async throws {
        let base = lastProfile
        let totals = SocialClock.Totals(today: base?.todaySeconds ?? 0, week: base?.weekSeconds ?? 0)
        try await publish(totals: totals, studyingSince: base?.studyingSince)
    }

    // MARK: 친구

    @discardableResult
    func addFriend(code input: String) async throws -> FriendRef {
        try requireSetUp()
        guard let code = SocialCode.extractFriendCode(from: input) else { throw SocialError.invalidCode }
        if code == state.friendCode { throw SocialError.selfCode }
        if state.friends.count >= SocialLimits.friendMax { throw SocialError.friendLimit }
        guard let profile = try await backend.findProfile(friendCode: code) else { throw SocialError.codeNotFound }
        if profile.id == state.profileID { throw SocialError.selfCode }
        if state.isBlocked(profile.id) { throw SocialError.blockedUser }
        if state.isFriend(profile.id) { throw SocialError.alreadyFriend }
        let ref = FriendRef(id: profile.id, nickname: profile.nickname, addedAt: now())
        mutate { $0.friends.append(ref) }
        return ref
    }

    func removeFriend(_ id: String) {
        mutate { $0.friends.removeAll { $0.id == id } }
    }

    /// 친구들의 지금 모습을 불러옴 (차단한 사람은 빼고, 못 찾은 사람은 profile nil)
    func refreshFriends() async throws -> [FriendRow] {
        try requireSetUp()
        let refs = state.friends.filter { !state.isBlocked($0.id) }
        guard !refs.isEmpty else { return [] }
        let found = try await backend.fetchProfiles(ids: refs.map(\.id))
        // 닉네임이 바뀌었으면 저장해 둠 (프로필을 못 불러올 때 보여 주려고)
        var changed = false
        var updated = state.friends
        for i in updated.indices {
            if let p = found[updated[i].id], p.nickname != updated[i].nickname {
                updated[i].nickname = p.nickname
                changed = true
            }
        }
        if changed { mutate { $0.friends = updated } }
        return refs.map { ref in FriendRow(ref: state.friends.first { $0.id == ref.id } ?? ref, profile: found[ref.id]) }
    }

    // MARK: 차단 · 신고

    /// 이 기기에서 그 사람을 숨기고 친구에서 뺌 (그룹 목록에서도 안 보임)
    func block(profileID: String, nickname: String) {
        mutate {
            $0.friends.removeAll { $0.id == profileID }
            if !$0.isBlocked(profileID) { $0.blocked.append(BlockedRef(id: profileID, nickname: nickname)) }
        }
    }

    func unblock(_ id: String) {
        mutate { $0.blocked.removeAll { $0.id == id } }
    }

    /// 신고: 차단은 바로 하고, 신고 기록은 네트워크가 없으면 나중에 다시 보냄
    func report(profileID: String, nickname: String, reason: ReportReason) async {
        let report = SocialReport(id: makeID(), reporterProfileID: state.profileID, reportedProfileID: profileID,
                                  reportedNickname: nickname, reason: reason, createdAt: now())
        block(profileID: profileID, nickname: nickname)
        do {
            try await backend.submitReport(report)
        } catch {
            mutate { $0.pendingReports.append(report) }
        }
    }

    /// 못 보낸 신고 다시 보내기
    func flushPendingReports() async {
        for report in state.pendingReports {
            do {
                try await backend.submitReport(report)
                mutate { $0.pendingReports.removeAll { $0.id == report.id } }
            } catch {
                return
            }
        }
    }

    // MARK: 그룹

    @discardableResult
    func createGroup(name raw: String) async throws -> StudyGroup {
        try requireSetUp()
        let name: String
        switch NicknameFilter.validateGroupName(raw) {
        case .ok(let text): name = text
        case .empty, .tooLong, .profanity: throw SocialError.groupNameInvalid
        }
        if state.groups.count >= SocialLimits.joinedGroupMax { throw SocialError.groupLimit }
        let at = now()
        let group = StudyGroup(id: makeID(), name: name, inviteCode: try await uniqueInviteCode(),
                               ownerProfileID: state.profileID, maxMembers: SocialLimits.maxMembers, createdAt: at)
        try await backend.saveGroup(group)
        do {
            try await backend.saveMember(GroupMember(groupID: group.id, profileID: state.profileID, joinedAt: at))
        } catch {
            try? await backend.deleteGroup(id: group.id)
            throw error
        }
        mutate { $0.groups.append(JoinedGroup(id: group.id, name: group.name, isOwner: true, joinedAt: at)) }
        return group
    }

    @discardableResult
    func joinGroup(code input: String) async throws -> StudyGroup {
        try requireSetUp()
        guard let code = SocialCode.extractInviteCode(from: input) else { throw SocialError.invalidCode }
        if state.groups.count >= SocialLimits.joinedGroupMax { throw SocialError.groupLimit }
        guard let group = try await backend.findGroup(inviteCode: code) else { throw SocialError.codeNotFound }
        if state.groups.contains(where: { $0.id == group.id }) { throw SocialError.alreadyMember }
        if group.removedProfileIDs.contains(state.profileID) { throw SocialError.removedFromGroup }

        let existing = try await backend.fetchMembers(groupID: group.id)
        let active = existing.filter { !group.removedProfileIDs.contains($0.profileID) }
        if active.count >= group.maxMembers { throw SocialError.groupFull }

        let at = now()
        try await backend.saveMember(GroupMember(groupID: group.id, profileID: state.profileID, joinedAt: at))
        // 동시에 여럿이 들어와 자리를 넘겼는지 다시 확인: 늦게 들어온 사람이 물러남
        let after = try await backend.fetchMembers(groupID: group.id)
            .filter { !group.removedProfileIDs.contains($0.profileID) }
            .sorted { ($0.joinedAt, $0.profileID) < ($1.joinedAt, $1.profileID) }
        if let index = after.firstIndex(where: { $0.profileID == state.profileID }), index >= group.maxMembers {
            try? await backend.deleteMember(groupID: group.id, profileID: state.profileID)
            throw SocialError.groupFull
        }
        let isOwner = group.ownerProfileID == state.profileID
        mutate { $0.groups.append(JoinedGroup(id: group.id, name: group.name, isOwner: isOwner, joinedAt: at)) }
        return group
    }

    /// 그룹 나가기 (만든 사람이 나가면 그룹이 없어짐)
    func leaveGroup(_ id: String) async throws {
        try requireSetUp()
        if state.groups.first(where: { $0.id == id })?.isOwner == true {
            try await deleteGroup(id)
            return
        }
        try await backend.deleteMember(groupID: id, profileID: state.profileID)
        mutate { $0.groups.removeAll { $0.id == id } }
    }

    func deleteGroup(_ id: String) async throws {
        try requireSetUp()
        guard state.groups.first(where: { $0.id == id })?.isOwner == true else { throw SocialError.notOwner }
        try await backend.deleteGroup(id: id)
        try? await backend.deleteMember(groupID: id, profileID: state.profileID)
        mutate { $0.groups.removeAll { $0.id == id } }
    }

    /// 만든 사람이 멤버 내보내기: 멤버 기록은 본인만 지울 수 있어서 그룹의 "내보낸 목록"에 올림.
    /// 내보낸 사람의 기기는 다음에 열 때 스스로 그룹을 정리함
    func removeMember(groupID: String, profileID: String) async throws {
        try requireSetUp()
        guard state.groups.first(where: { $0.id == groupID })?.isOwner == true else { throw SocialError.notOwner }
        guard profileID != state.profileID else { throw SocialError.notOwner }
        guard var group = try await backend.fetchGroup(id: groupID) else { throw SocialError.groupGone }
        guard group.ownerProfileID == state.profileID else { throw SocialError.notOwner }
        if !group.removedProfileIDs.contains(profileID) { group.removedProfileIDs.append(profileID) }
        try await backend.saveGroup(group)
    }

    /// 그룹 화면: 멤버와 그들의 프로필 (차단한 사람 · 내보낸 사람은 뺌)
    func loadGroup(_ id: String) async throws -> GroupDetail {
        try requireSetUp()
        guard let group = try await backend.fetchGroup(id: id) else {
            await forgetGroup(id)
            throw SocialError.groupGone
        }
        if group.removedProfileIDs.contains(state.profileID) {
            await forgetGroup(id)
            throw SocialError.removedFromGroup
        }
        let members = try await backend.fetchMembers(groupID: id)
            .filter { !group.removedProfileIDs.contains($0.profileID) && !state.isBlocked($0.profileID) }
        let profiles = try await backend.fetchProfiles(ids: members.map(\.profileID))
        let rows = members.compactMap { m -> GroupMemberRow? in
            guard let p = profiles[m.profileID] else { return nil }
            return GroupMemberRow(profile: p, joinedAt: m.joinedAt, isMe: m.profileID == state.profileID,
                                  isOwner: m.profileID == group.ownerProfileID)
        }
        // 이름이 바뀌었으면 이 기기 목록도 맞춤
        if state.groups.first(where: { $0.id == id })?.name != group.name {
            mutate { s in if let i = s.groups.firstIndex(where: { $0.id == id }) { s.groups[i].name = group.name } }
        }
        return GroupDetail(group: group, members: rows, iAmOwner: group.ownerProfileID == state.profileID)
    }

    /// 없어졌거나 내보내진 그룹을 이 기기에서 정리 (내 멤버 기록도 지움)
    private func forgetGroup(_ id: String) async {
        try? await backend.deleteMember(groupID: id, profileID: state.profileID)
        mutate { $0.groups.removeAll { $0.id == id } }
    }

    // MARK: 내 정보 지우기

    /// "친구 기능 끄고 내 정보 지우기": 내 그룹 멤버 기록 · 내가 만든 그룹 · 내 프로필을 지우고 이 기기 상태도 비움
    /// 하나라도 실패하면 던짐 (기기 상태는 그대로라서 다시 시도할 수 있음)
    func deleteEverything() async throws {
        let profileID = state.profileID
        guard !profileID.isEmpty else {
            mutate { $0 = SocialState() }
            return
        }
        var memberships = Set(try await backend.fetchMemberships(profileID: profileID).map(\.groupID))
        for g in state.groups { memberships.insert(g.id) }
        var owned = Set(try await backend.fetchGroups(ownerProfileID: profileID).map(\.id))
        for g in state.groups where g.isOwner { owned.insert(g.id) }
        for groupID in memberships.sorted() {
            try await backend.deleteMember(groupID: groupID, profileID: profileID)
        }
        for groupID in owned.sorted() {
            try await backend.deleteGroup(id: groupID)
        }
        try await backend.deleteProfile(id: profileID)
        let owner = state.iCloudOwner
        lastProfile = nil
        mutate { $0 = SocialState(); $0.iCloudOwner = owner }
    }
}
