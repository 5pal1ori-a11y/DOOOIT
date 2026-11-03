import AuthenticationServices
import CommonCrypto
import CryptoKit
import Foundation
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import Observation
import Security
import UIKit

struct UserAccount: Codable, Equatable {
    enum Provider: String, Codable {
        case apple, email, google

        var title: String {
            switch self {
            case .apple: return "Apple로 로그인"
            case .google: return "Google로 로그인"
            case .email: return "이메일 계정"
            }
        }
        var symbol: String {
            switch self {
            case .apple: return "applelogo"
            case .google: return "g.circle.fill"
            case .email: return "envelope.fill"
            }
        }
    }

    var id: String
    var name: String
    var email: String
    var provider: Provider
    var createdAt: Date
}

enum AuthError: LocalizedError {
    case invalidName
    case invalidEmail
    case weakPassword
    case passwordMismatch
    case emailExists
    case wrongCredentials
    case locked(Int)
    case apple(String)
    case google(String)

    var errorDescription: String? {
        switch self {
        case .invalidName: return "이름을 입력해주세요."
        case .invalidEmail: return "올바른 이메일 주소를 입력해주세요."
        case .weakPassword: return "비밀번호는 8자 이상이어야 해요."
        case .passwordMismatch: return "비밀번호가 서로 달라요."
        case .emailExists: return "이미 가입된 이메일이에요. 로그인해주세요."
        case .wrongCredentials: return "이메일 또는 비밀번호가 올바르지 않아요."
        case .locked(let seconds):
            return seconds >= 60 ? "로그인 시도가 너무 많아요. \((seconds + 59) / 60)분 뒤에 다시 시도해주세요."
                                 : "로그인 시도가 너무 많아요. \(seconds)초 뒤에 다시 시도해주세요."
        case .apple(let message): return "Apple 로그인에 실패했어요. \(message)"
        case .google(let message): return "Google 로그인에 실패했어요. \(message)"
        }
    }
}

/// 로그인 / 회원가입 관리
/// - 현재는 서버 없이 기기 안(Keychain)에만 계정을 저장하는 로컬 방식입니다.
///   여러 기기 동기화가 필요하면 Firebase Auth, Supabase 등 백엔드로 교체해야 합니다.
@MainActor
@Observable
final class AuthManager {
    private(set) var currentUser: UserAccount?

    private let currentUserKey = "dooit.currentUser"
    private let emailAccountsKey = "dooit.emailAccounts"
    private let failureKey = "dooit.auth.failures"

    /// 비밀번호 해시 방식: 1 = SHA256(salt+비밀번호) 한 번 (예전), 2 = PBKDF2-HMAC-SHA256 반복
    private static let currentHashVersion = 2
    private static let pbkdf2Rounds: UInt32 = 120_000

    private struct StoredAccount: Codable {
        var id: String
        var name: String
        var salt: String
        var hash: String
        var createdAt: Date
        /// nil이면 예전 방식(1). 로그인에 성공하면 새 방식으로 바꿔 저장
        var version: Int?
    }

    /// 로그인 실패 기록 (연속 실패하면 잠깐 잠금)
    private struct Failures: Codable {
        var count = 0
        var lockedUntil: Date?
    }

    private struct AppleProfile: Codable {
        var name: String
        var email: String
    }

    init() {
        // 로그인 정보(이름·이메일)는 Keychain에 보관. 예전 버전이 UserDefaults에 둔 값은 옮기고 지움
        if let data = Keychain.get(currentUserKey),
           let user = try? JSONDecoder().decode(UserAccount.self, from: data) {
            currentUser = user
        } else if let data = UserDefaults.standard.data(forKey: currentUserKey),
                  let user = try? JSONDecoder().decode(UserAccount.self, from: data) {
            currentUser = user
            Keychain.set(data, for: currentUserKey)
        }
        UserDefaults.standard.removeObject(forKey: currentUserKey)
    }

    // MARK: Apple

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) throws {
        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled { return }
            throw AuthError.apple(error.localizedDescription)

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthError.apple("인증 정보를 확인할 수 없어요.")
            }
            let userID = credential.user
            let profileKey = "apple.\(userID)"
            var profile = Keychain.get(profileKey).flatMap { try? JSONDecoder().decode(AppleProfile.self, from: $0) }
                ?? AppleProfile(name: "", email: "")

            // 이름/이메일은 최초 1회만 전달되므로 Keychain에 보관
            let name = [credential.fullName?.familyName, credential.fullName?.givenName]
                .compactMap { $0 }
                .joined()
            if !name.isEmpty { profile.name = name }
            if let email = credential.email { profile.email = email }
            if let data = try? JSONEncoder().encode(profile) { Keychain.set(data, for: profileKey) }

            setUser(UserAccount(id: userID, name: profile.name, email: profile.email, provider: .apple, createdAt: Date()))
        }
    }

    // MARK: Google

    /// Google 계정으로 로그인 (같은 Google 계정이면 같은 두잇 계정 → 저장소가 이어짐)
    func signInWithGoogle() async throws {
        #if canImport(GoogleSignIn)
        guard let presenter = Self.topViewController() else { throw AuthError.google("화면을 찾을 수 없어요.") }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            let user = result.user
            guard let googleID = user.userID else { throw AuthError.google("계정 정보를 확인할 수 없어요.") }
            let id = "google.\(googleID)"
            let saved = Keychain.get("google.name.\(id)").flatMap { String(data: $0, encoding: .utf8) }
            let name = saved ?? user.profile?.name ?? ""
            let email = user.profile?.email ?? ""
            setUser(UserAccount(id: id, name: name, email: email, provider: .google, createdAt: Date()))
        } catch let error as AuthError {
            throw error
        } catch {
            // 사용자가 취소하면 조용히
            if (error as NSError).code == GIDSignInError.canceled.rawValue { return }
            throw AuthError.google(error.localizedDescription)
        }
        #else
        throw AuthError.google("이 빌드에서는 사용할 수 없어요.")
        #endif
    }

    /// Google 로그인 화면에서 돌아온 주소 처리
    static func handleGoogleURL(_ url: URL) -> Bool {
        #if canImport(GoogleSignIn)
        return GIDSignIn.sharedInstance.handle(url)
        #else
        return false
        #endif
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    /// Apple ID 연결이 해제되었는지 확인
    func verifyAppleCredential() async {
        guard let user = currentUser, user.provider == .apple else { return }
        let state: ASAuthorizationAppleIDProvider.CredentialState = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: user.id) { state, _ in
                continuation.resume(returning: state)
            }
        }
        // 연결 해제(revoked) 또는 Apple ID에서 찾을 수 없음(notFound) → 로그아웃
        if state == .revoked || state == .notFound {
            signOut()
        }
    }

    // MARK: Email

    func signUp(name: String, email: String, password: String, confirm: String) throws {
        let name = name.trimmingCharacters(in: .whitespaces)
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { throw AuthError.invalidName }
        guard Self.isValidEmail(email) else { throw AuthError.invalidEmail }
        guard password.count >= 8, password.count <= 256 else { throw AuthError.weakPassword }
        guard password == confirm else { throw AuthError.passwordMismatch }

        var accounts = loadAccounts()
        guard accounts[email] == nil else { throw AuthError.emailExists }

        let salt = Self.randomSalt()
        let account = StoredAccount(id: UUID().uuidString, name: name, salt: salt,
                                    hash: Self.pbkdf2(password, salt: salt), createdAt: Date(), version: Self.currentHashVersion)
        accounts[email] = account
        saveAccounts(accounts)
        setUser(UserAccount(id: account.id, name: name, email: email, provider: .email, createdAt: account.createdAt))
    }

    func signIn(email: String, password: String) throws {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard Self.isValidEmail(email) else { throw AuthError.invalidEmail }

        // 연속 실패로 잠긴 상태인지
        var failures = loadFailures()
        if let until = failures.lockedUntil, until > Date() {
            throw AuthError.locked(Int(until.timeIntervalSinceNow.rounded(.up)))
        }

        var accounts = loadAccounts()
        guard var account = accounts[email], Self.verify(password, account: account) else {
            // 5번 넘게 틀리면 30초부터 두 배씩 (최대 15분) 잠금
            failures.count += 1
            if failures.count >= 5 {
                let seconds = min(30.0 * pow(2.0, Double(failures.count - 5)), 900)
                failures.lockedUntil = Date().addingTimeInterval(seconds)
            }
            saveFailures(failures)
            throw AuthError.wrongCredentials
        }
        saveFailures(Failures())

        // 예전 방식으로 저장된 비밀번호는 새 방식으로 다시 저장
        if (account.version ?? 1) < Self.currentHashVersion {
            account.salt = Self.randomSalt()
            account.hash = Self.pbkdf2(password, salt: account.salt)
            account.version = Self.currentHashVersion
            accounts[email] = account
            saveAccounts(accounts)
        }
        setUser(UserAccount(id: account.id, name: account.name, email: email, provider: .email, createdAt: account.createdAt))
    }

    // MARK: Profile

    func updateName(_ name: String) {
        guard var user = currentUser else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        user.name = trimmed
        setUser(user)

        switch user.provider {
        case .email:
            var accounts = loadAccounts()
            if var account = accounts[user.email] {
                account.name = trimmed
                accounts[user.email] = account
                saveAccounts(accounts)
            }
        case .google:
            // 이름을 바꿨으면 다음 Google 로그인 때도 그 이름을 씀
            Keychain.set(Data(trimmed.utf8), for: "google.name.\(user.id)")
        case .apple:
            let key = "apple.\(user.id)"
            let profile = AppleProfile(name: trimmed, email: user.email)
            if let data = try? JSONEncoder().encode(profile) { Keychain.set(data, for: key) }
        }
    }

    func signOut() {
        #if canImport(GoogleSignIn)
        if currentUser?.provider == .google { GIDSignIn.sharedInstance.signOut() }
        #endif
        currentUser = nil
        Keychain.delete(currentUserKey)
        UserDefaults.standard.removeObject(forKey: currentUserKey)
    }

    func deleteAccount() {
        guard let user = currentUser else { return }
        switch user.provider {
        case .email:
            var accounts = loadAccounts()
            accounts[user.email] = nil
            saveAccounts(accounts)
        case .apple:
            Keychain.delete("apple.\(user.id)")
        case .google:
            Keychain.delete("google.name.\(user.id)")
            #if canImport(GoogleSignIn)
            GIDSignIn.sharedInstance.disconnect { _ in }
            #endif
        }
        // 예전 버전이 남긴 크레딧 기록도 지움
        Keychain.delete("dooit.credits.v1")
        Keychain.delete(failureKey)
        signOut()
    }

    #if DEBUG
    /// 화면 사진 찍기용 데모 계정 (키체인에 저장하지 않음 · Debug 빌드에서만)
    func useUIShotAccount(_ user: UserAccount?) {
        currentUser = user
    }
    #endif

    // MARK: Private

    private func setUser(_ user: UserAccount) {
        currentUser = user
        if let data = try? JSONEncoder().encode(user) {
            Keychain.set(data, for: currentUserKey)
        }
    }

    private func loadFailures() -> Failures {
        Keychain.get(failureKey).flatMap { try? JSONDecoder().decode(Failures.self, from: $0) } ?? Failures()
    }

    private func saveFailures(_ failures: Failures) {
        if failures.count == 0 && failures.lockedUntil == nil {
            Keychain.delete(failureKey)
        } else if let data = try? JSONEncoder().encode(failures) {
            Keychain.set(data, for: failureKey)
        }
    }

    private func loadAccounts() -> [String: StoredAccount] {
        guard let data = Keychain.get(emailAccountsKey),
              let accounts = try? JSONDecoder().decode([String: StoredAccount].self, from: data) else { return [:] }
        return accounts
    }

    private func saveAccounts(_ accounts: [String: StoredAccount]) {
        if let data = try? JSONEncoder().encode(accounts) {
            Keychain.set(data, for: emailAccountsKey)
        }
    }

    /// 예전 방식 (버전 1): SHA256(salt + 비밀번호) — 기존 계정 확인용으로만 사용
    private static func legacyHash(_ password: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + password).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 새 방식 (버전 2): PBKDF2-HMAC-SHA256, 12만 번 반복, 32바이트
    private static func pbkdf2(_ password: String, salt: String) -> String {
        let passwordData = Array(password.utf8)
        let saltData = Array(salt.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let status = passwordData.withUnsafeBufferPointer { passwordBuffer in
            saltData.withUnsafeBufferPointer { saltBuffer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBuffer.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) },
                    passwordData.count,
                    saltBuffer.baseAddress,
                    saltData.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    pbkdf2Rounds,
                    &derived,
                    derived.count
                )
            }
        }
        guard status == Int32(kCCSuccess) else { return legacyHash(password, salt: salt) }
        return derived.map { String(format: "%02x", $0) }.joined()
    }

    private static func verify(_ password: String, account: StoredAccount) -> Bool {
        let expected = (account.version ?? 1) >= 2 ? pbkdf2(password, salt: account.salt) : legacyHash(password, salt: account.salt)
        return constantTimeEqual(expected, account.hash)
    }

    /// 글자 수가 같으면 끝까지 비교 (어디서 달라지는지 시간으로 알 수 없게)
    private static func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        guard x.count == y.count else { return false }
        var difference: UInt8 = 0
        for i in 0..<x.count { difference |= x[i] ^ y[i] }
        return difference == 0
    }

    /// 무작위 16바이트 소금값 (hex)
    private static func randomSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            return UUID().uuidString
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func isValidEmail(_ email: String) -> Bool {
        email.range(of: #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil
    }
}

// MARK: - Keychain

enum Keychain {
    private static let service = "com.bravekoon.dooit"

    private static func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    static func set(_ data: Data, for key: String) {
        let query = baseQuery(key)
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        // 이 기기에서만, 처음 잠금 해제 뒤에 읽을 수 있음 (백업으로 다른 기기에 옮겨지지 않음)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func get(_ key: String) -> Data? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    static func delete(_ key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }
}
