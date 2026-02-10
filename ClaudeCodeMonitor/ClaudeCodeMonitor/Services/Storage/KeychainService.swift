import Foundation
import Security

/// Protocol for keychain operations
protocol KeychainServiceProtocol {
    func saveAPIKey(_ key: String) throws
    func loadAPIKey() throws -> String?
    func deleteAPIKey() throws
    func validateAPIKeyFormat(_ key: String) -> Bool
}

/// Keychain service for secure API key storage
@available(macOS 14.0, *)
final class KeychainService: KeychainServiceProtocol {
    private let service = "com.claudecode.monitor"
    private let account = "admin-api-key"

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save API key to Keychain (status: \(status))"
            case .loadFailed(let status):
                return "Failed to load API key from Keychain (status: \(status))"
            case .deleteFailed(let status):
                return "Failed to delete API key from Keychain (status: \(status))"
            case .invalidFormat:
                return "Invalid API key format. Admin keys must start with 'sk-ant-admin-'"
            }
        }
    }

    /// Save API key to macOS Keychain
    func saveAPIKey(_ key: String) throws {
        guard validateAPIKeyFormat(key) else {
            throw KeychainError.invalidFormat
        }

        // Convert key to data
        guard let keyData = key.data(using: .utf8) else {
            throw KeychainError.saveFailed(errSecParam)
        }

        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Load API key from macOS Keychain
    func loadAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.loadFailed(status)
        }

        return key
    }

    /// Delete API key from Keychain
    func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Validate API key format
    /// Admin API keys must start with "sk-ant-admin-"
    func validateAPIKeyFormat(_ key: String) -> Bool {
        return key.hasPrefix("sk-ant-admin-") && key.count > 20
    }
}
