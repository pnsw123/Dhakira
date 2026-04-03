import Foundation
import OSLog
import Security

private let log = Logger(subsystem: "notes.Note-taking", category: "Keychain")

/// Minimal Keychain wrapper for storing and retrieving string tokens securely.
/// Used by GoogleAuthService to persist OAuth access and refresh tokens.
enum KeychainHelper {

    @discardableResult
    static func save(key: String, value: String) -> Bool {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        // Delete any existing item first, then add fresh.
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            log.warning("Keychain delete failed for '\(key)': status \(deleteStatus)")
        }

        let attributes: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData:   data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        if addStatus != errSecSuccess {
            log.error("Keychain save FAILED for '\(key)': status \(addStatus)")
            return false
        }
        log.debug("Keychain save OK for '\(key)'")
        return true
    }

    static func read(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            log.warning("Keychain delete failed for '\(key)': status \(status)")
        }
    }
}
