import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security

struct UserAccount: Codable, Equatable {
    enum Provider: String, Codable {
        case apple, email

        var title: String { self == .apple ? "Apple로 로그인" : "이메일 계정" }
        var symbol: String { self == .apple ? "applelogo" : "envelope.fill" }
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
    case apple(String)

    var errorDescription: String? {
        switch self {
        case .invalidName: return "이름을 입력해주세요."
        case .invalidEmail: return "올바른 이메일 주소를 입력해주세요."
        case .weakPassword: return "비밀번호는 8자 이상이어야 해요."
        case .passwordMismatch: return "비밀번호가 서로 달라요."
        case .emailExists: return "이미 가입된 이메일이에요. 로그인해주세요."
        case .wrongCredentials: return "이메일 또는 비밀번호가 올바르지 않아요."
        case .apple(let message): return "Apple 로그인에 실패했어요. \(message)"
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

    private struct StoredAccount: Codable {
        var id: String
        var name: String
        var salt: String
        var hash: String
        var createdAt: Date
    }

    private struct AppleProfile: Codable {
        var name: String
        var email: String
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: currentUserKey),
           let user = try? JSONDecoder().decode(UserAccount.self, from: data) {
            currentUser = user
        }
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

    /// Apple ID 연결이 해제되었는지 확인
    func verifyAppleCredential() async {
        guard let user = currentUser, user.provider == .apple else { return }
        let state: ASAuthorizationAppleIDProvider.CredentialState = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: user.id) { state, _ in
                continuation.resume(returning: state)
            }
        }
        if state == .revoked {
            signOut()
        }
    }

    // MARK: Email

    func signUp(name: String, email: String, password: String, confirm: String) throws {
        let name = name.trimmingCharacters(in: .whitespaces)
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { throw AuthError.invalidName }
        guard Self.isValidEmail(email) else { throw AuthError.invalidEmail }
        guard password.count >= 8 else { throw AuthError.weakPassword }
        guard password == confirm else { throw AuthError.passwordMismatch }

        var accounts = loadAccounts()
        guard accounts[email] == nil else { throw AuthError.emailExists }

        let salt = UUID().uuidString
        let account = StoredAccount(id: UUID().uuidString, name: name, salt: salt,
                                    hash: Self.hash(password, salt: salt), createdAt: Date())
        accounts[email] = account
        saveAccounts(accounts)
        setUser(UserAccount(id: account.id, name: name, email: email, provider: .email, createdAt: account.createdAt))
    }

    func signIn(email: String, password: String) throws {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard Self.isValidEmail(email) else { throw AuthError.invalidEmail }
        guard let account = loadAccounts()[email],
              account.hash == Self.hash(password, salt: account.salt) else {
            throw AuthError.wrongCredentials
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
        case .apple:
            let key = "apple.\(user.id)"
            let profile = AppleProfile(name: trimmed, email: user.email)
            if let data = try? JSONEncoder().encode(profile) { Keychain.set(data, for: key) }
        }
    }

    func signOut() {
        currentUser = nil
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
        }
        signOut()
    }

    // MARK: Private

    private func setUser(_ user: UserAccount) {
        currentUser = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: currentUserKey)
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

    private static func hash(_ password: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + password).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
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
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
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
