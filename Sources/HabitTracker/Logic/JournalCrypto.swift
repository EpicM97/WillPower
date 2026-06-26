import Foundation
import CryptoKit

/// Field-level encryption for journal notes — the private memory vault.
///
/// A note is sealed on-device with a symmetric key that never leaves the device
/// (`JournalKeyStore`), so the at-rest value — in SwiftData *and* synced to
/// Supabase — is ciphertext. True E2EE: no server, AI, or provider can read it.
///
/// Trade-off (surfaced to the user, never silent): losing the device key — a
/// reinstall without a Keychain restore — makes past notes unreadable. That is
/// the cost of owner-only encryption with no server-held key.
enum JournalCrypto {
    /// Marks our sealed payloads so legacy plaintext notes (written before
    /// encryption) are recognised and passed through rather than mis-decrypted.
    static let marker = "wpx1:"

    /// Seals plaintext → `"wpx1:<base64(AES-GCM combined)>"`. Empty/whitespace
    /// input returns nil (nothing to store).
    static func seal(_ plaintext: String, key: SymmetricKey) -> String? {
        let trimmed = plaintext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let sealed = try? AES.GCM.seal(Data(trimmed.utf8), using: key),
              let combined = sealed.combined else { return nil }
        return marker + combined.base64EncodedString()
    }

    /// Opens a stored value. Unmarked strings are treated as legacy plaintext and
    /// returned as-is. A marked-but-undecryptable value (wrong key / corruption)
    /// returns nil so the UI can show a "locked" placeholder, not garbage.
    static func open(_ stored: String?, key: SymmetricKey) -> String? {
        guard let stored, !stored.isEmpty else { return nil }
        guard stored.hasPrefix(marker) else { return stored } // legacy plaintext
        let b64 = String(stored.dropFirst(marker.count))
        guard let data = Data(base64Encoded: b64),
              let box = try? AES.GCM.SealedBox(combined: data),
              let opened = try? AES.GCM.open(box, using: key) else { return nil }
        return String(decoding: opened, as: UTF8.self)
    }

    /// Whether a stored value is one of our sealed payloads.
    static func isSealed(_ stored: String?) -> Bool {
        stored?.hasPrefix(marker) ?? false
    }
}
