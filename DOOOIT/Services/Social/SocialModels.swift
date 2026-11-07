import Foundation

// 친구 · 그룹: 데이터 모양 (Foundation만 씀 → 리눅스 테스트에서 그대로 돌려 봄)
//
// 서버 없이 CloudKit 공용 데이터베이스(iCloud.com.donghyeon.moti)에 넣는 기록 네 가지:
//   MotiProfile  내 프로필 (닉네임 · 친구 코드 · 오늘/이번 주 공부 시간 · 공부 중 표시)
//   StudyGroup   그룹 (이름 · 초대 코드 · 만든 사람 · 내보낸 사람)
//   GroupMember  그룹 멤버 한 명 (그룹 · 프로필 · 들어온 때)
//   MotiReport   신고 (만든 사람만 쓸 수 있고, 개발자만 대시보드에서 읽음)
// CloudKit 호출은 SocialBackend 뒤에 두고, 여기서는 일반 딕셔너리(SocialFields)로만 주고받아요.

enum SocialRecordType {
    static let profile = "MotiProfile"
    static let group = "StudyGroup"
    static let member = "GroupMember"
    static let report = "MotiReport"

    /// 종류마다 가진 필드 이름 (필드를 지울 때(예: 공부 중 표시 끄기) 어떤 키를 비워야 하는지 알려고)
    static func fieldKeys(_ type: String) -> [String] {
        switch type {
        case profile: return SocialProfile.fieldKeys
        case group: return StudyGroup.fieldKeys
        case member: return GroupMember.fieldKeys
        case report: return SocialReport.fieldKeys
        default: return []
        }
    }
}

/// CloudKit 필드 값 (문자열 · 정수 · 날짜 · 문자열 목록). CloudKit에는 참/거짓이 없어서 정수 0/1로
enum SocialValue: Equatable {
    case string(String)
    case int(Int)
    case date(Date)
    case stringList([String])
}

typealias SocialFields = [String: SocialValue]

extension Dictionary where Key == String, Value == SocialValue {
    func string(_ key: String) -> String? { if case .string(let v)? = self[key] { return v }; return nil }
    func int(_ key: String) -> Int? { if case .int(let v)? = self[key] { return v }; return nil }
    func date(_ key: String) -> Date? { if case .date(let v)? = self[key] { return v }; return nil }
    func list(_ key: String) -> [String]? { if case .stringList(let v)? = self[key] { return v }; return nil }
}

/// 이 기기에 저장하는 키 (계정마다 따로: AccountStore.personalKeys에 넣음)
enum SocialKeys {
    static let state = "social.state"
    static var all: [String] { [state] }
}

enum SocialLimits {
    static let nicknameMax = 12
    static let groupNameMax = 20
    static let maxMembers = 20
    static let friendMax = 50
    static let joinedGroupMax = 5
    /// 하루/한 주 공부 시간으로 믿을 수 있는 최대 (잘못된 값이 와도 화면이 깨지지 않게)
    static let daySecondsMax = 24 * 3600
    static let weekSecondsMax = 7 * 24 * 3600
}

// MARK: - 프로필

struct SocialProfile: Equatable, Identifiable {
    var id: String
    var nickname: String
    var friendCode: String
    var todaySeconds: Int = 0
    var todayKey: String = ""
    var weekSeconds: Int = 0
    var weekKey: String = ""
    /// 공부 중이면 (쉰 시간을 뺀) 시작한 것으로 치는 시각
    var studyingSince: Date?
    var updatedAt: Date
    /// true면 닉네임만 보임 (시간 · 공부 중 표시는 아예 올리지 않음)
    var isHidden: Bool = false
    /// 누구의 친구 코드로 시작했는지 (처음 추가한 친구의 프로필 id. 초대 보상 같은 기능이 읽음. 없으면 nil)
    var invitedBy: String?

    static let fieldKeys = ["nickname", "friendCode", "todaySeconds", "todayKey", "weekSeconds", "weekKey",
                            "studyingSince", "updatedAt", "isHidden", "invitedBy"]

    func fields() -> SocialFields {
        var f: SocialFields = [
            "nickname": .string(nickname),
            "friendCode": .string(friendCode),
            "todaySeconds": .int(todaySeconds),
            "todayKey": .string(todayKey),
            "weekSeconds": .int(weekSeconds),
            "weekKey": .string(weekKey),
            "updatedAt": .date(updatedAt),
            "isHidden": .int(isHidden ? 1 : 0)
        ]
        if let studyingSince { f["studyingSince"] = .date(studyingSince) }
        if let invitedBy, !invitedBy.isEmpty { f["invitedBy"] = .string(invitedBy) }
        return f
    }

    init(id: String, nickname: String, friendCode: String, todaySeconds: Int = 0, todayKey: String = "",
         weekSeconds: Int = 0, weekKey: String = "", studyingSince: Date? = nil, updatedAt: Date, isHidden: Bool = false,
         invitedBy: String? = nil) {
        self.id = id
        self.nickname = nickname
        self.friendCode = friendCode
        self.todaySeconds = todaySeconds
        self.todayKey = todayKey
        self.weekSeconds = weekSeconds
        self.weekKey = weekKey
        self.studyingSince = studyingSince
        self.updatedAt = updatedAt
        self.isHidden = isHidden
        self.invitedBy = invitedBy
    }

    /// 받은 기록 → 프로필. 값이 이상해도 범위 안으로 (남이 올린 값은 믿지 않음)
    init?(id: String, fields f: SocialFields) {
        guard let nickname = f.string("nickname") else { return nil }
        self.id = id
        self.nickname = String(nickname.prefix(SocialLimits.nicknameMax))
        self.friendCode = f.string("friendCode") ?? ""
        self.todaySeconds = min(max(0, f.int("todaySeconds") ?? 0), SocialLimits.daySecondsMax)
        self.todayKey = f.string("todayKey") ?? ""
        self.weekSeconds = min(max(0, f.int("weekSeconds") ?? 0), SocialLimits.weekSecondsMax)
        self.weekKey = f.string("weekKey") ?? ""
        self.studyingSince = f.date("studyingSince")
        self.updatedAt = f.date("updatedAt") ?? Date(timeIntervalSince1970: 0)
        self.isHidden = (f.int("isHidden") ?? 0) != 0
        self.invitedBy = f.string("invitedBy").flatMap { $0.isEmpty ? nil : String($0.prefix(64)) }
    }
}

// MARK: - 그룹

struct StudyGroup: Equatable, Identifiable {
    var id: String
    var name: String
    var inviteCode: String
    var ownerProfileID: String
    var maxMembers: Int = SocialLimits.maxMembers
    var createdAt: Date
    /// 만든 사람이 내보낸 프로필 (멤버 기록은 본인만 지울 수 있어서, 목록에서 빼고 본인 기기가 스스로 정리)
    var removedProfileIDs: [String] = []

    static let fieldKeys = ["name", "inviteCode", "ownerProfileID", "maxMembers", "createdAt", "removedProfileIDs"]

    func fields() -> SocialFields {
        [
            "name": .string(name),
            "inviteCode": .string(inviteCode),
            "ownerProfileID": .string(ownerProfileID),
            "maxMembers": .int(maxMembers),
            "createdAt": .date(createdAt),
            "removedProfileIDs": .stringList(removedProfileIDs)
        ]
    }

    init(id: String, name: String, inviteCode: String, ownerProfileID: String, maxMembers: Int = SocialLimits.maxMembers,
         createdAt: Date, removedProfileIDs: [String] = []) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.ownerProfileID = ownerProfileID
        self.maxMembers = maxMembers
        self.createdAt = createdAt
        self.removedProfileIDs = removedProfileIDs
    }

    init?(id: String, fields f: SocialFields) {
        guard let name = f.string("name"), let owner = f.string("ownerProfileID") else { return nil }
        self.id = id
        self.name = String(name.prefix(SocialLimits.groupNameMax))
        self.inviteCode = f.string("inviteCode") ?? ""
        self.ownerProfileID = owner
        self.maxMembers = min(max(1, f.int("maxMembers") ?? SocialLimits.maxMembers), SocialLimits.maxMembers)
        self.createdAt = f.date("createdAt") ?? Date(timeIntervalSince1970: 0)
        self.removedProfileIDs = f.list("removedProfileIDs") ?? []
    }
}

struct GroupMember: Equatable, Identifiable {
    var groupID: String
    var profileID: String
    var joinedAt: Date

    var id: String { Self.recordName(groupID: groupID, profileID: profileID) }

    /// 기록 이름을 정해 두면 (그룹, 프로필) 한 쌍이 하나만 생기고, 지울 때 찾기도 쉬움
    static func recordName(groupID: String, profileID: String) -> String { "gm.\(groupID).\(profileID)" }

    static let fieldKeys = ["groupID", "profileID", "joinedAt"]

    func fields() -> SocialFields {
        ["groupID": .string(groupID), "profileID": .string(profileID), "joinedAt": .date(joinedAt)]
    }

    init(groupID: String, profileID: String, joinedAt: Date) {
        self.groupID = groupID
        self.profileID = profileID
        self.joinedAt = joinedAt
    }

    init?(fields f: SocialFields) {
        guard let g = f.string("groupID"), let p = f.string("profileID") else { return nil }
        self.init(groupID: g, profileID: p, joinedAt: f.date("joinedAt") ?? Date(timeIntervalSince1970: 0))
    }
}

// MARK: - 신고

enum ReportReason: String, CaseIterable, Codable, Identifiable {
    case inappropriateName, harassment, spam, other
    var id: String { rawValue }
}

struct SocialReport: Equatable, Identifiable, Codable {
    var id: String
    var reporterProfileID: String
    var reportedProfileID: String
    /// 신고한 때 보인 닉네임 (개발자가 대시보드에서 알아보기 쉽게)
    var reportedNickname: String
    var reason: ReportReason
    var createdAt: Date

    static let fieldKeys = ["reporterProfileID", "reportedProfileID", "reportedNickname", "reason", "createdAt"]

    func fields() -> SocialFields {
        [
            "reporterProfileID": .string(reporterProfileID),
            "reportedProfileID": .string(reportedProfileID),
            "reportedNickname": .string(reportedNickname),
            "reason": .string(reason.rawValue),
            "createdAt": .date(createdAt)
        ]
    }
}

// MARK: - 이 기기에 저장하는 내용

struct FriendRef: Codable, Equatable, Identifiable {
    var id: String
    /// 마지막으로 본 닉네임 (프로필을 못 불러올 때 보여 줌)
    var nickname: String
    var addedAt: Date
}

struct BlockedRef: Codable, Equatable, Identifiable {
    var id: String
    var nickname: String
}

struct JoinedGroup: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var isOwner: Bool
    var joinedAt: Date
}

/// 계정마다 따로 저장하는 친구 · 그룹 상태 (UserDefaults에 JSON 하나로)
struct SocialState: Codable, Equatable {
    /// 첫 안내에 동의하고 프로필을 만들었는지
    var enabled = false
    var profileID = ""
    var friendCode = ""
    var nickname = ""
    /// 내 공부 상태 보여주기 (끄면 닉네임만)
    var showStatus = true
    /// 이 프로필을 만든 iCloud 계정 (다른 계정으로 바뀌면 처음부터)
    var iCloudOwner = ""
    /// 시작한 때 · 처음 추가한 친구 (초대로 시작했는지 가늠하는 데 씀. 시작 3일 안에 처음 추가한 친구만 인정)
    var setUpAt: Date?
    var invitedBy: String?
    var friends: [FriendRef] = []
    var blocked: [BlockedRef] = []
    var groups: [JoinedGroup] = []
    /// 네트워크가 없어서 못 보낸 신고 (다음에 연결되면 보냄)
    var pendingReports: [SocialReport] = []

    func isBlocked(_ id: String) -> Bool { blocked.contains { $0.id == id } }
    func isFriend(_ id: String) -> Bool { friends.contains { $0.id == id } }

    static func decode(_ data: Data?) -> SocialState {
        guard let data, let s = try? JSONDecoder().decode(SocialState.self, from: data) else { return SocialState() }
        return s
    }

    func encoded() -> Data? { try? JSONEncoder().encode(self) }
}

/// UserDefaults에 읽고 쓰기 (테스트에서는 따로 만든 UserDefaults를 넣음)
struct SocialStateStore {
    var defaults: UserDefaults = .standard

    func load() -> SocialState { SocialState.decode(defaults.data(forKey: SocialKeys.state)) }

    func save(_ state: SocialState) {
        if let data = state.encoded() { defaults.set(data, forKey: SocialKeys.state) }
    }

    func clear() { defaults.removeObject(forKey: SocialKeys.state) }
}
