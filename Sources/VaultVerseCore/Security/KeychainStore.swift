import Foundation
import Security

/// Thin wrapper over the macOS Keychain for the only secrets VaultVerse holds:
/// the Music User Token and any `.p8` reference for the live Apple Music path.
///
/// Tokens never live in the database, in model structs, in logs, or in exports —
/// only here. `ConnectedAccount.tokenKeychainRef` stores just the account key.
public struct KeychainStore: Sendable {
    public let service: String

    public init(service: String = "com.vaultverse.tokens") {
        self.service = service
    }

    public func set(_ value: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultVerseError.persistenceFailure("keychain write failed (OSStatus \(status))")
        }
    }

    public func get(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw VaultVerseError.persistenceFailure("keychain read failed (OSStatus \(status))")
        }
        return value
    }

    public func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VaultVerseError.persistenceFailure("keychain delete failed (OSStatus \(status))")
        }
    }
}
