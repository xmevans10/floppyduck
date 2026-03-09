import Foundation
import Security

final class IdentityStore {
    static let shared = IdentityStore()

    private enum Key {
        static let deviceId = "device_id"
        static let sessionToken = "session_token"
        static let appleUserId = "apple_user_id"
        static let didCompleteAuthOnboarding = "didCompleteAuthOnboarding"
        static let didMergeLocalStats = "didMergeLocalStats"
    }

    private let keychainService = "com.xmevans10.FloppyDuck.identity"
    private let defaults = UserDefaults.standard

    private init() {}

    var didCompleteAuthOnboarding: Bool {
        get { defaults.bool(forKey: Key.didCompleteAuthOnboarding) }
        set { defaults.set(newValue, forKey: Key.didCompleteAuthOnboarding) }
    }

    var didMergeLocalStats: Bool {
        get { defaults.bool(forKey: Key.didMergeLocalStats) }
        set { defaults.set(newValue, forKey: Key.didMergeLocalStats) }
    }

    var sessionToken: String? {
        get { readString(for: Key.sessionToken) }
        set { writeString(newValue, for: Key.sessionToken) }
    }

    var appleUserId: String? {
        get { readString(for: Key.appleUserId) }
        set { writeString(newValue, for: Key.appleUserId) }
    }

    func getOrCreateDeviceId() -> String {
        if let existing = readString(for: Key.deviceId), !existing.isEmpty {
            return existing
        }

        let created = UUID().uuidString.lowercased()
        writeString(created, for: Key.deviceId)
        return created
    }

    private func writeString(_ value: String?, for account: String) {
        if let value {
            let data = Data(value.utf8)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: account,
            ]

            let attributes: [String: Any] = [
                kSecValueData as String: data,
            ]

            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status == errSecItemNotFound {
                var create = query
                create[kSecValueData as String] = data
                SecItemAdd(create as CFDictionary, nil)
            }
        } else {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: account,
            ]
            SecItemDelete(query as CFDictionary)
        }
    }

    private func readString(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
