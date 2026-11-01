import CryptoKit
import Foundation
import SwiftData

/// 계정마다 따로 쓰는 데이터 저장소와 개인 설정
/// - 저장소: Application Support/Accounts/<계정 해시>/DOOOIT.store
/// - 개인 설정(목표, D-Day, 테마 등): 계정을 바꿀 때 지금 계정 것은 보관하고 새 계정 것을 꺼냄
/// - 예전 버전의 공용 저장소(default.store)는 업데이트 뒤 처음 로그인한 계정이 이어받음
@MainActor
enum AccountStore {
    static let schema = Schema([
        Plan.self, PlanCategory.self, Word.self, MathNote.self, Memo.self, StudySession.self,
        ExamPlan.self, StudyContent.self, QuizRecord.self, AIQuestion.self,
        // 새로 추가한 모델은 끝에 (기존 저장소에 자동으로 표가 더해짐 — 기존 데이터는 그대로)
        WeakConcept.self
    ])

    /// 계정마다 따로 저장하는 설정 키
    static let personalKeys: [String] = [
        SettingsKey.dailyWordGoal, SettingsKey.dailyStudyGoalMinutes, SettingsKey.wordGoalDoneKey,
        SettingsKey.reminderLeadMinutes, SettingsKey.notificationsEnabled, SettingsKey.liveActivityEnabled,
        SettingsKey.autoStartTimer, SettingsKey.appearance, SettingsKey.themeColor,
        SettingsKey.dDayTitle, SettingsKey.dDayDate, "selectedTab", "doitUserName", "dooit.autoStartedPlanKeys"
    ]

    private static let legacyClaimedKey = "accounts.legacyStoreClaimed"
    private static let activeKey = "accounts.activeSettingsOwner"
    private static let pendingRemovalKey = "accounts.pendingRemoval"

    // MARK: 저장소

    /// 계정 저장소 열기 (로그인 전에는 메모리에만 있는 빈 저장소)
    static func container(for userID: String?) -> ModelContainer {
        guard let userID else { return memoryContainer() }
        let folder = folder(for: userID)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        claimLegacyStoreIfNeeded(into: folder)
        let url = folder.appending(path: "DOOOIT.store")
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        } catch {
            // 열 수 없으면 (예: 형식이 맞지 않음) 앱이 매번 꺼지지 않도록 기존 파일을 백업해 두고 새로 시작
            let stamp = Int(Date().timeIntervalSince1970)
            for suffix in ["", "-shm", "-wal"] {
                let file = folder.appending(path: "DOOOIT.store\(suffix)")
                if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
                    try? FileManager.default.moveItem(at: file, to: folder.appending(path: "DOOOIT.store\(suffix).backup-\(stamp)"))
                }
            }
            if let fresh = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url)) { return fresh }
            return memoryContainer()
        }
    }

    private static func memoryContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        } catch {
            fatalError("메모리 저장소를 만들 수 없어요: \(error)")
        }
    }

    /// 계정 아이디를 그대로 폴더 이름으로 쓰지 않고 해시로 (특수문자·개인정보 방지)
    static func folder(for userID: String) -> URL {
        let digest = SHA256.hash(data: Data(userID.utf8)).map { String(format: "%02x", $0) }.joined()
        return URL.applicationSupportDirectory.appending(path: "Accounts").appending(path: String(digest.prefix(32)))
    }

    /// 예전 공용 저장소를 처음 로그인한 계정 폴더로 옮김 (한 번만)
    private static func claimLegacyStoreIfNeeded(into folder: URL) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: legacyClaimedKey) else { return }
        defaults.set(true, forKey: legacyClaimedKey)
        let support = URL.applicationSupportDirectory
        let target = folder.appending(path: "DOOOIT.store")
        guard !FileManager.default.fileExists(atPath: target.path(percentEncoded: false)) else { return }
        for (old, new) in [("default.store", "DOOOIT.store"), ("default.store-shm", "DOOOIT.store-shm"), ("default.store-wal", "DOOOIT.store-wal")] {
            let source = support.appending(path: old)
            if FileManager.default.fileExists(atPath: source.path(percentEncoded: false)) {
                try? FileManager.default.moveItem(at: source, to: folder.appending(path: new))
            }
        }
    }

    // MARK: 개인 설정

    /// 지금 설정을 원래 계정에 보관하고, 새 계정의 설정을 꺼냄
    static func switchSettings(to userID: String?) {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: activeKey)
        if previous == userID { return }
        let removing = defaults.string(forKey: pendingRemovalKey)
        if let previous, removing != folder(for: previous).path(percentEncoded: false) {
            var saved: [String: Any] = [:]
            for key in personalKeys { if let value = defaults.object(forKey: key) { saved[key] = value } }
            defaults.set(saved, forKey: settingsKey(previous))
        }
        // 새 계정: 보관해 둔 설정이 있으면 꺼내고, 없으면 기본값 (단, 업데이트 전부터 쓰던 첫 계정은 지금 설정 그대로)
        if let userID {
            if let saved = defaults.dictionary(forKey: settingsKey(userID)) {
                for key in personalKeys { defaults.removeObject(forKey: key) }
                for (key, value) in saved { defaults.set(value, forKey: key) }
            } else if previous != nil {
                for key in personalKeys { defaults.removeObject(forKey: key) }
            }
            defaults.set(userID, forKey: activeKey)
        } else {
            for key in personalKeys { defaults.removeObject(forKey: key) }
            defaults.removeObject(forKey: activeKey)
        }
    }

    private static func settingsKey(_ userID: String) -> String {
        "accounts.settings." + String(SHA256.hash(data: Data(userID.utf8)).map { String(format: "%02x", $0) }.joined().prefix(32))
    }

    // MARK: 계정 삭제

    /// 계정을 지울 때: 저장소가 닫힌 뒤 폴더를 지우도록 표시하고, 보관한 설정도 지움
    static func scheduleRemoval(of userID: String) {
        UserDefaults.standard.set(folder(for: userID).path(percentEncoded: false), forKey: pendingRemovalKey)
        UserDefaults.standard.removeObject(forKey: settingsKey(userID))
        if UserDefaults.standard.string(forKey: activeKey) == userID {
            // 지금 쓰던 계정이면 화면에 남아 있는 개인 설정도 바로 지움 (다음 계정에 넘어가지 않게)
            for key in personalKeys { UserDefaults.standard.removeObject(forKey: key) }
            UserDefaults.standard.removeObject(forKey: activeKey)
        }
    }

    /// 다른 저장소로 바꾼 뒤 지울 폴더가 있으면 지움
    static func removePendingIfNeeded() {
        guard let path = UserDefaults.standard.string(forKey: pendingRemovalKey) else { return }
        try? FileManager.default.removeItem(atPath: path)
        UserDefaults.standard.removeObject(forKey: pendingRemovalKey)
    }
}
