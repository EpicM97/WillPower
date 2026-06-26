import Foundation
import CryptoKit
import Security

/// Get-or-create the device-local journal encryption key in the Keychain. The
/// key is never synced (no iCloud Keychain), never exported — owner-device only.
/// `AfterFirstUnlock` so the background midnight rollover can still seal notes.
struct JournalKeyStore {
    private let service = "com.willpower.HabitTracker.journal"
    private let account = "journal-key-v1"

    /// The device key, creating + persisting one on first use.
    func key() -> SymmetricKey {
        if let existing = load() { return existing }
        let fresh = SymmetricKey(size: .bits256)
        save(fresh)
        return fresh
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func load() -> SymmetricKey? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    private func save(_ key: SymmetricKey) {
        let data = key.withUnsafeBytes { Data($0) }
        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }
}
