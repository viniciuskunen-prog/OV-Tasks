import Foundation
import Security

public enum ClickUpKeychainError: Error, Equatable {
    case invalidAccount
    case invalidToken
    case missingCredential
    case osStatus(Int)
}

/// Local-only secure storage. Never writes an access token to UserDefaults,
/// SQLite, source files, command arguments, GitHub, logs or preferences.
/// An installed app's signing identity must remain stable to retain Keychain access.
public actor ClickUpKeychain: ClickUpCredentialSource {
    public static let shared = ClickUpKeychain()

    private let service = "studio.ov.OVTasks.clickup.personal-token"

    public init() {}

    public func save(_ token: String, for accountID: String) throws {
        guard !accountID.isEmpty, !accountID.contains("\n"),
              !accountID.contains("\r") else {
            throw ClickUpKeychainError.invalidAccount
        }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed == token,
              !trimmed.contains("\n"), !trimmed.contains("\r"),
              let data = token.data(using: .utf8) else {
            throw ClickUpKeychainError.invalidToken
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID
        ]
        // Update atomically first. An error must not destroy an existing token.
        let updated: [String: Any] = [kSecValueData as String: data]
        let updateCode = SecItemUpdate(query as CFDictionary, updated as CFDictionary)
        if updateCode == errSecSuccess { return }
        guard updateCode == errSecItemNotFound else {
            throw ClickUpKeychainError.osStatus(Int(updateCode))
        }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let code = SecItemAdd(add as CFDictionary, nil)
        guard code == errSecSuccess else {
            throw ClickUpKeychainError.osStatus(Int(code))
        }
    }

    public func token(for accountID: String) throws -> String {
        guard !accountID.isEmpty else { throw ClickUpKeychainError.invalidAccount }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var value: CFTypeRef?
        let code = SecItemCopyMatching(query as CFDictionary, &value)
        if code == errSecItemNotFound { throw ClickUpKeychainError.missingCredential }
        guard code == errSecSuccess else {
            throw ClickUpKeychainError.osStatus(Int(code))
        }
        guard let data = value as? Data, let secret = String(data: data, encoding: .utf8),
              !secret.isEmpty else {
            throw ClickUpKeychainError.invalidToken
        }
        return secret
    }

    public func remove(for accountID: String) throws {
        guard !accountID.isEmpty else { throw ClickUpKeychainError.invalidAccount }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID
        ]
        let code = SecItemDelete(query as CFDictionary)
        guard code == errSecSuccess || code == errSecItemNotFound else {
            throw ClickUpKeychainError.osStatus(Int(code))
        }
    }
}
