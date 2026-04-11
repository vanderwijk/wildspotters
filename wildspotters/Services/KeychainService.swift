import Foundation
import Security
import OSLog

enum KeychainService {

    private static let service = "nl.wildspotters.app"
    private static let tokenKey = "jwt_token"
    private static let logger = Logger(subsystem: "nl.wildspotters.app", category: "Keychain")

    static func saveToken(_ token: String) throws {
        let data = Data(token.utf8)

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status != errSecSuccess {
            if status != errSecItemNotFound {
                logger.error("\(KeychainError.loadFailed(status).localizedDescription, privacy: .public)")
            }
            return nil
        }

        guard let data = result as? Data else {
            logger.error("\(KeychainError.loadFailed(errSecInternalError).localizedDescription, privacy: .public)")
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("\(KeychainError.deleteFailed(status).localizedDescription, privacy: .public)")
        }
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            "Keychain save failed with status \(status)"
        case .loadFailed(let status):
            "Keychain load failed with status \(status)"
        case .deleteFailed(let status):
            "Keychain delete failed with status \(status)"
        }
    }
}
