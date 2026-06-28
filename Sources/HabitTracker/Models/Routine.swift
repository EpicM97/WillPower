import Foundation

/// How a habit is tracked. `.checkIn` is a yes/no done; `.count` accumulates
/// toward a daily `target`.
enum HabitType: Int, Codable, CaseIterable, Sendable {
    case checkIn = 0
    case count = 1
}

/// Coarse grouping used by stats + theming. Intentionally small for MVP.
enum HabitCategory: Int, Codable, CaseIterable, Sendable {
    case health = 0
    case lifestyle = 1
}

/// Fixed time-of-day buckets a habit belongs to. A habit can be in 1+ routines.
/// User-defined custom routines are deferred to V1; these four are built in and
/// carry a default clock window used for ordering (and, later, reminders).
enum Routine: Int, Codable, CaseIterable, Sendable, Identifiable {
    case morning = 0
    case noon = 1
    case afternoon = 2
    case evening = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .noon: return "Noon"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }

    /// Default start of this bucket, in minutes from midnight. Drives sort order
    /// on the Today screen and seeds per-habit reminders later.
    var defaultStartMinute: Int {
        switch self {
        case .morning: return 6 * 60     // 06:00
        case .noon: return 12 * 60       // 12:00
        case .afternoon: return 15 * 60  // 15:00
        case .evening: return 19 * 60    // 19:00
        }
    }
}
