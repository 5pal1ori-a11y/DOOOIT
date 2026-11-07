import CloudKit
import Foundation

/// 진짜 클라우드: CloudKit 공용 데이터베이스 (iCloud.com.donghyeon.moti). 따로 서버 없음.
/// 기록 이름 = 프로필 · 그룹 id(무작위 UUID), 멤버는 "gm.<그룹>.<프로필>". 필드는 SocialFields 그대로 옮김.
/// 표 모양은 Config/CloudKitSchema.ckdb (MotiProfile · StudyGroup · GroupMember · MotiReport) (CloudKit Console에서 가져오고 Production에 올려야 동작)
final class CloudKitSocialBackend: SocialBackend, @unchecked Sendable {
    private let container: CKContainer
    private var database: CKDatabase { container.publicCloudDatabase }
    private let lock = NSLock()
    /// 내가 쓴 기록의 서버 정보(변경 표시)를 들고 있어서, 다음 갱신 때 다시 불러오지 않음
    private var cache: [String: CKRecord] = [:]
    /// 서버 표(스키마)에 totalSeconds가 아직 없어서 거절당했는지 (그러면 그 필드만 빼고 올림)
    private var totalFieldRejected = false

    init(containerID: String = AccountStore.cloudContainer) {
        container = CKContainer(identifier: containerID)
    }

    // MARK: 계정

    func accountStatus() async -> SocialAccountStatus {
        guard let status = try? await container.accountStatus() else { return .unavailable }
        switch status {
        case .available: return .available
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        default: return .unavailable
        }
    }

    func accountToken() async throws -> String {
        do {
            return try await container.userRecordID().recordName
        } catch {
            throw Self.map(error)
        }
    }

    // MARK: 프로필

    func saveProfile(_ profile: SocialProfile) async throws {
        var fields = profile.fields()
        if isTotalFieldRejected {
            fields["totalSeconds"] = nil
            try await save(type: SocialRecordType.profile, name: profile.id, fields: fields)
            return
        }
        do {
            try await save(type: SocialRecordType.profile, name: profile.id, fields: fields)
        } catch SocialError.server(_) {
            // 새 필드(totalSeconds)를 서버 표에 아직 안 올렸을 수 있음: 그 필드만 빼고 다시 올림 (친구 기능은 계속 동작)
            fields["totalSeconds"] = nil
            try await save(type: SocialRecordType.profile, name: profile.id, fields: fields)
            setTotalFieldRejected()
        }
    }

    private var isTotalFieldRejected: Bool { lock.lock(); defer { lock.unlock() }; return totalFieldRejected }
    private func setTotalFieldRejected() { lock.lock(); totalFieldRejected = true; lock.unlock() }

    func fetchProfiles(ids: [String]) async throws -> [String: SocialProfile] {
        let records = try await fetchRecords(names: ids)
        var out: [String: SocialProfile] = [:]
        for (name, record) in records {
            if let p = SocialProfile(id: name, fields: Self.fields(of: record, type: SocialRecordType.profile)) { out[name] = p }
        }
        return out
    }

    func findProfile(friendCode: String) async throws -> SocialProfile? {
        let records = try await query(type: SocialRecordType.profile, field: "friendCode", equals: friendCode, limit: 1)
        guard let record = records.first else { return nil }
        return SocialProfile(id: record.recordID.recordName, fields: Self.fields(of: record, type: SocialRecordType.profile))
    }

    func deleteProfile(id: String) async throws { try await delete(name: id) }

    func fetchInvited(by profileID: String) async throws -> [SocialProfile] {
        let records = try await query(type: SocialRecordType.profile, field: "invitedBy", equals: profileID, limit: 50)
        return records.compactMap { SocialProfile(id: $0.recordID.recordName, fields: Self.fields(of: $0, type: SocialRecordType.profile)) }
    }

    // MARK: 그룹

    func saveGroup(_ group: StudyGroup) async throws {
        try await save(type: SocialRecordType.group, name: group.id, fields: group.fields())
    }

    func fetchGroup(id: String) async throws -> StudyGroup? {
        guard let record = try await fetchRecords(names: [id])[id] else { return nil }
        return StudyGroup(id: id, fields: Self.fields(of: record, type: SocialRecordType.group))
    }

    func findGroup(inviteCode: String) async throws -> StudyGroup? {
        let records = try await query(type: SocialRecordType.group, field: "inviteCode", equals: inviteCode, limit: 1)
        guard let record = records.first else { return nil }
        return StudyGroup(id: record.recordID.recordName, fields: Self.fields(of: record, type: SocialRecordType.group))
    }

    func fetchGroups(ownerProfileID: String) async throws -> [StudyGroup] {
        let records = try await query(type: SocialRecordType.group, field: "ownerProfileID", equals: ownerProfileID, limit: 50)
        return records.compactMap { StudyGroup(id: $0.recordID.recordName, fields: Self.fields(of: $0, type: SocialRecordType.group)) }
    }

    func deleteGroup(id: String) async throws { try await delete(name: id) }

    // MARK: 멤버

    func saveMember(_ member: GroupMember) async throws {
        try await save(type: SocialRecordType.member, name: member.id, fields: member.fields())
    }

    func fetchMembers(groupID: String) async throws -> [GroupMember] {
        let records = try await query(type: SocialRecordType.member, field: "groupID", equals: groupID, limit: 100)
        return records.compactMap { GroupMember(fields: Self.fields(of: $0, type: SocialRecordType.member)) }
    }

    func fetchMemberships(profileID: String) async throws -> [GroupMember] {
        let records = try await query(type: SocialRecordType.member, field: "profileID", equals: profileID, limit: 100)
        return records.compactMap { GroupMember(fields: Self.fields(of: $0, type: SocialRecordType.member)) }
    }

    func deleteMember(groupID: String, profileID: String) async throws {
        try await delete(name: GroupMember.recordName(groupID: groupID, profileID: profileID))
    }

    // MARK: 신고

    func submitReport(_ report: SocialReport) async throws {
        let record = CKRecord(recordType: SocialRecordType.report, recordID: CKRecord.ID(recordName: report.id))
        Self.apply(report.fields(), to: record, keys: SocialReport.fieldKeys)
        do {
            _ = try await database.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            return // 같은 신고가 이미 올라갔음
        } catch {
            throw Self.map(error)
        }
    }

    // MARK: 공통

    private func cached(_ name: String) -> CKRecord? { lock.lock(); defer { lock.unlock() }; return cache[name] }
    private func remember(_ record: CKRecord?, for name: String) {
        lock.lock(); defer { lock.unlock() }
        cache[name] = record
    }

    /// 있으면 불러와서 고치고, 없으면 새로 만듦 (내가 만든 기록만 고칠 수 있음)
    private func save(type: String, name: String, fields: SocialFields) async throws {
        let id = CKRecord.ID(recordName: name)
        var record: CKRecord
        if let c = cached(name) {
            record = c
        } else {
            do {
                record = try await database.record(for: id)
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: type, recordID: id)
            } catch {
                throw Self.map(error)
            }
        }
        Self.apply(fields, to: record, keys: SocialRecordType.fieldKeys(type))
        do {
            let saved = try await database.save(record)
            remember(saved, for: name)
        } catch {
            remember(nil, for: name)
            throw Self.map(error)
        }
    }

    private func delete(name: String) async throws {
        remember(nil, for: name)
        do {
            _ = try await database.deleteRecord(withID: CKRecord.ID(recordName: name))
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch {
            throw Self.map(error)
        }
    }

    /// 이름으로 여러 개 불러옴 (없는 것은 빠짐)
    private func fetchRecords(names: [String]) async throws -> [String: CKRecord] {
        var out: [String: CKRecord] = [:]
        var index = 0
        while index < names.count {
            let chunk = Array(names[index..<min(index + 100, names.count)])
            index += 100
            do {
                let results = try await database.records(for: chunk.map { CKRecord.ID(recordName: $0) })
                for (id, result) in results {
                    switch result {
                    case .success(let record): out[id.recordName] = record
                    case .failure(let error):
                        if let ck = error as? CKError, ck.code == .unknownItem { continue }
                        throw Self.map(error)
                    }
                }
            } catch {
                throw Self.map(error)
            }
        }
        return out
    }

    private func query(type: String, field: String, equals value: String, limit: Int) async throws -> [CKRecord] {
        let q = CKQuery(recordType: type, predicate: NSPredicate(format: "%K == %@", field, value))
        do {
            let (matches, _) = try await database.records(matching: q, resultsLimit: limit)
            return try matches.map { try $0.1.get() }
        } catch {
            throw Self.map(error, query: true)
        }
    }

    // MARK: 필드 옮기기

    /// keys 가운데 값이 없는 것은 비움 (예: 공부 중 표시 끄기)
    static func apply(_ fields: SocialFields, to record: CKRecord, keys: [String]) {
        for key in keys {
            guard let value = fields[key] else { record[key] = nil; continue }
            switch value {
            case .string(let s): record[key] = s as NSString
            case .int(let i): record[key] = NSNumber(value: i)
            case .date(let d): record[key] = d as NSDate
            case .stringList(let l): record[key] = l as NSArray
            }
        }
    }

    static func fields(of record: CKRecord, type: String) -> SocialFields {
        var out: SocialFields = [:]
        for key in SocialRecordType.fieldKeys(type) {
            guard let value = record[key] else { continue }
            if let d = value as? Date { out[key] = .date(d) }
            else if let s = value as? String { out[key] = .string(s) }
            else if let l = value as? [String] { out[key] = .stringList(l) }
            else if let n = value as? NSNumber { out[key] = .int(n.intValue) }
        }
        return out
    }

    // MARK: 오류 바꾸기

    static func map(_ error: Error, query: Bool = false) -> SocialError {
        if let e = error as? SocialError { return e }
        guard let ck = error as? CKError else { return .server(error.localizedDescription) }
        switch ck.code {
        case .notAuthenticated: return .noAccount
        case .managedAccountRestricted: return .restricted
        case .networkUnavailable, .networkFailure, .serverResponseLost: return .network
        case .requestRateLimited, .zoneBusy, .serviceUnavailable: return .rateLimited(ck.retryAfterSeconds ?? 30)
        case .permissionFailure: return .permissionDenied
        case .unknownItem: return query ? .unavailable : .notFound
        case .invalidArguments: return query ? .unavailable : .server("invalid")
        case .badContainer, .missingEntitlement, .incompatibleVersion: return .unavailable
        case .partialFailure:
            if let first = ck.partialErrorsByItemID?.values.first { return map(first, query: query) }
            return .server("partial")
        default: return .server(ck.localizedDescription)
        }
    }
}
