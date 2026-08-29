import Foundation
import OtpVaultCore
import Security

struct KeychainStore: KeyValueStore {
    let service: String

    func data(forKey key: String) -> Data? {
        Keychain.read(service: service, account: key)
    }

    func set(_ data: Data, forKey key: String) {
        try? Keychain.write(data, service: service, account: key)
    }

    func removeValue(forKey key: String) {
        Keychain.delete(service: service, account: key)
    }
}

enum Keychain {
    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }

    static func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func write(_ data: Data, service: String, account: String) throws {
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let payload: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(identity as CFDictionary, payload as CFDictionary)
        if updateStatus == errSecItemNotFound {
            let addStatus = SecItemAdd(identity.merging(payload) { $1 } as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
        } else {
            guard updateStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(updateStatus) }
        }
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
