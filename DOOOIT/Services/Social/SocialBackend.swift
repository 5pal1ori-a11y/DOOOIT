import Foundation

enum SocialAccountStatus: Equatable {
    case available
    case noAccount
    case restricted
    case unavailable
}

enum SocialError: Error, Equatable {
    // 환경
    case noAccount
    case restricted
    case network
    case rateLimited(TimeInterval)
    /// CloudKit 표 모양이 아직 없음 등 (개발자가 스키마를 올리지 않은 경우 포함)
    case unavailable
    case server(String)
    // 기록
    case notFound
    case permissionDenied
    // 사용자 입력 · 규칙
    case notSetUp
    case nicknameEmpty
    case nicknameTooLong
    case nicknameRejected
    case invalidCode
    case codeNotFound
    case selfCode
    case alreadyFriend
    case blockedUser
    case friendLimit
    case groupNameInvalid
    case groupLimit
    case groupFull
    case alreadyMember
    case notOwner
    case groupGone
    case removedFromGroup
}

/// 클라우드와 주고받는 일 전부. 진짜는 CloudKit 공용 데이터베이스(CloudKitSocialBackend),
/// 테스트 · 화면 사진용은 메모리 가짜(InMemorySocialBackend)
protocol SocialBackend: AnyObject, Sendable {
    func accountStatus() async -> SocialAccountStatus
    /// 이 기기 iCloud 계정을 구분하는 값 (계정이 바뀌었는지 알아보려고)
    func accountToken() async throws -> String

    func saveProfile(_ profile: SocialProfile) async throws
    func fetchProfiles(ids: [String]) async throws -> [String: SocialProfile]
    func findProfile(friendCode: String) async throws -> SocialProfile?
    func deleteProfile(id: String) async throws
    /// 나를 초대한 사람으로 적은(invitedBy) 프로필들 (초대 보상용. 한 번에 최대 50명)
    func fetchInvited(by profileID: String) async throws -> [SocialProfile]

    func saveGroup(_ group: StudyGroup) async throws
    func fetchGroup(id: String) async throws -> StudyGroup?
    func findGroup(inviteCode: String) async throws -> StudyGroup?
    func fetchGroups(ownerProfileID: String) async throws -> [StudyGroup]
    func deleteGroup(id: String) async throws

    func saveMember(_ member: GroupMember) async throws
    func fetchMembers(groupID: String) async throws -> [GroupMember]
    func fetchMemberships(profileID: String) async throws -> [GroupMember]
    func deleteMember(groupID: String, profileID: String) async throws

    func submitReport(_ report: SocialReport) async throws
}

// MARK: - 메모리 가짜 (테스트 · 화면 사진용)

/// 여러 사람(iCloud 계정)이 함께 쓰는 가짜 클라우드. 진짜 보안 규칙과 같게:
/// 읽기는 누구나, 쓰기는 만든 사람만, 신고는 만들기만 (읽을 수 없음)
final class FakeCloud: @unchecked Sendable {
    private let lock = NSLock()
    fileprivate var profiles: [String: SocialProfile] = [:]
    fileprivate var groups: [String: StudyGroup] = [:]
    fileprivate var members: [String: GroupMember] = [:]
    fileprivate(set) var reports: [SocialReport] = []
    /// 기록을 처음 만든 사람 (기록 이름 → 계정)
    fileprivate var creators: [String: String] = [:]

    init() {}

    fileprivate func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }

    var profileCount: Int { locked { profiles.count } }
    var groupCount: Int { locked { groups.count } }
    var memberCount: Int { locked { members.count } }
    var reportCount: Int { locked { reports.count } }

    /// 화면 사진 · 테스트용: 권한 검사 없이 넣기
    func seed(profile: SocialProfile, creator: String) {
        locked { profiles[profile.id] = profile; creators[profile.id] = creator }
    }
    func seed(group: StudyGroup, creator: String) {
        locked { groups[group.id] = group; creators[group.id] = creator }
    }
    func seed(member: GroupMember, creator: String) {
        locked { members[member.id] = member; creators[member.id] = creator }
    }
}

final class InMemorySocialBackend: SocialBackend, @unchecked Sendable {
    let cloud: FakeCloud
    let user: String
    private let lock = NSLock()
    private var status: SocialAccountStatus
    private var queuedFailures: [SocialError] = []
    private var _callCount = 0

    init(cloud: FakeCloud = FakeCloud(), user: String = "user-1", status: SocialAccountStatus = .available) {
        self.cloud = cloud
        self.user = user
        self.status = status
    }

    // 테스트용 조작
    func setStatus(_ s: SocialAccountStatus) { lock.lock(); status = s; lock.unlock() }
    /// 다음 호출 하나를 실패시킴
    func failNext(_ error: SocialError) { lock.lock(); queuedFailures.append(error); lock.unlock() }
    var callCount: Int { lock.lock(); defer { lock.unlock() }; return _callCount }

    private func enter() throws {
        lock.lock(); defer { lock.unlock() }
        _callCount += 1
        if !queuedFailures.isEmpty { throw queuedFailures.removeFirst() }
        switch status {
        case .available: break
        case .noAccount: throw SocialError.noAccount
        case .restricted: throw SocialError.restricted
        case .unavailable: throw SocialError.network
        }
    }

    private func currentStatus() -> SocialAccountStatus { lock.lock(); defer { lock.unlock() }; return status }
    func accountStatus() async -> SocialAccountStatus { currentStatus() }
    func accountToken() async throws -> String { try enter(); return user }

    private func canWrite(_ recordName: String) -> Bool {
        guard let creator = cloud.creators[recordName] else { return true }
        return creator == user
    }

    func saveProfile(_ profile: SocialProfile) async throws {
        try enter()
        try cloud.locked {
            guard canWrite(profile.id) else { throw SocialError.permissionDenied }
            cloud.profiles[profile.id] = profile
            cloud.creators[profile.id] = cloud.creators[profile.id] ?? user
        }
    }

    func fetchProfiles(ids: [String]) async throws -> [String: SocialProfile] {
        try enter()
        return cloud.locked {
            var out: [String: SocialProfile] = [:]
            for id in ids { if let p = cloud.profiles[id] { out[id] = p } }
            return out
        }
    }

    func findProfile(friendCode: String) async throws -> SocialProfile? {
        try enter()
        return cloud.locked { cloud.profiles.values.first { $0.friendCode == friendCode } }
    }

    func deleteProfile(id: String) async throws {
        try enter()
        try cloud.locked {
            guard cloud.profiles[id] != nil else { return }
            guard canWrite(id) else { throw SocialError.permissionDenied }
            cloud.profiles[id] = nil
            cloud.creators[id] = nil
        }
    }

    func fetchInvited(by profileID: String) async throws -> [SocialProfile] {
        try enter()
        return cloud.locked {
            Array(cloud.profiles.values.filter { $0.invitedBy == profileID }.sorted { $0.id < $1.id }.prefix(50))
        }
    }

    func saveGroup(_ group: StudyGroup) async throws {
        try enter()
        try cloud.locked {
            guard canWrite(group.id) else { throw SocialError.permissionDenied }
            cloud.groups[group.id] = group
            cloud.creators[group.id] = cloud.creators[group.id] ?? user
        }
    }

    func fetchGroup(id: String) async throws -> StudyGroup? {
        try enter()
        return cloud.locked { cloud.groups[id] }
    }

    func findGroup(inviteCode: String) async throws -> StudyGroup? {
        try enter()
        return cloud.locked { cloud.groups.values.first { $0.inviteCode == inviteCode } }
    }

    func fetchGroups(ownerProfileID: String) async throws -> [StudyGroup] {
        try enter()
        return cloud.locked { cloud.groups.values.filter { $0.ownerProfileID == ownerProfileID }.sorted { $0.id < $1.id } }
    }

    func deleteGroup(id: String) async throws {
        try enter()
        try cloud.locked {
            guard cloud.groups[id] != nil else { return }
            guard canWrite(id) else { throw SocialError.permissionDenied }
            cloud.groups[id] = nil
            cloud.creators[id] = nil
        }
    }

    func saveMember(_ member: GroupMember) async throws {
        try enter()
        try cloud.locked {
            guard canWrite(member.id) else { throw SocialError.permissionDenied }
            cloud.members[member.id] = member
            cloud.creators[member.id] = cloud.creators[member.id] ?? user
        }
    }

    func fetchMembers(groupID: String) async throws -> [GroupMember] {
        try enter()
        return cloud.locked { cloud.members.values.filter { $0.groupID == groupID }.sorted { $0.id < $1.id } }
    }

    func fetchMemberships(profileID: String) async throws -> [GroupMember] {
        try enter()
        return cloud.locked { cloud.members.values.filter { $0.profileID == profileID }.sorted { $0.id < $1.id } }
    }

    func deleteMember(groupID: String, profileID: String) async throws {
        try enter()
        let name = GroupMember.recordName(groupID: groupID, profileID: profileID)
        try cloud.locked {
            guard cloud.members[name] != nil else { return }
            guard canWrite(name) else { throw SocialError.permissionDenied }
            cloud.members[name] = nil
            cloud.creators[name] = nil
        }
    }

    func submitReport(_ report: SocialReport) async throws {
        try enter()
        cloud.locked { cloud.reports.append(report) }
    }
}
