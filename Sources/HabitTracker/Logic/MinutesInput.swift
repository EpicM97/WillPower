import Foundation

/// Pure helpers for a strictly-numeric "minutes" text field: strip anything
/// that isn't a digit (so the field can't hold `nvarchar`), then parse into a
/// clamped Int with a sane fallback (never a stray tiny value).
enum MinutesInput {
    static let fallback = 15
    static let range = 1...600

    /// Digits only, capped at 3 chars (max is 600 → 3 digits).
    static func sanitize(_ raw: String) -> String {
        String(raw.filter(\.isNumber).prefix(3))
    }

    /// Parse sanitized text into a valid minute count. Empty / zero / garbage
    /// → `fallback`; otherwise clamped to `range`.
    static func minutes(from text: String) -> Int {
        guard let n = Int(text), n >= range.lowerBound else { return fallback }
        return min(n, range.upperBound)
    }

    /// Clamp an Int into `range` — used by the −/+ stepper buttons.
    static func clamped(_ n: Int) -> Int {
        min(max(n, range.lowerBound), range.upperBound)
    }

    /// When the authoritative `value` changes, decide what the editable text
    /// should display. Returns `nil` to leave the field untouched — so a
    /// momentarily-empty / in-progress edit isn't clobbered when its parsed
    /// value already equals `value` (e.g. "" parses to the fallback == value).
    static func reconcile(text: String, value: Int) -> String? {
        minutes(from: text) == value ? nil : String(value)
    }
}
