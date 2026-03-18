import Foundation
import Security

protocol IdentityStoring: AnyObject {
    var didCompleteAuthOnboarding: Bool { get set }
    var didMergeLocalStats: Bool { get set }
    var sessionToken: String? { get set }
    var appleUserId: String? { get set }

    func getOrCreateDeviceId() -> String
}

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

            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if updateStatus == errSecItemNotFound {
                var create = query
                create[kSecValueData as String] = data
                let addStatus = SecItemAdd(create as CFDictionary, nil)
                if addStatus != errSecSuccess {
                    print("[IdentityStore] Keychain write failed for \(account): \(addStatus)")
                }
            } else if updateStatus != errSecSuccess {
                print("[IdentityStore] Keychain update failed for \(account): \(updateStatus)")

                // If update fails for an unexpected reason, delete & re-add as fallback.
                SecItemDelete(query as CFDictionary)
                var create = query
                create[kSecValueData as String] = data
                let retryStatus = SecItemAdd(create as CFDictionary, nil)
                if retryStatus != errSecSuccess {
                    print("[IdentityStore] Keychain retry write failed for \(account): \(retryStatus)")
                }
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

extension IdentityStore: IdentityStoring {}
