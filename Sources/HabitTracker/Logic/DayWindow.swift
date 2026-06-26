import Foundation

/// The user's active day: when it starts, when it ends, an optional explicit
/// wind-down time, and — kept deliberately *separate* — the discretionary habit
/// budget. The window drives start/wind-down nudges and anchors; it is **not**
/// the budget (budget ≠ waking hours). All times are minutes-from-midnight.
struct DayWindow: Equatable, Codable, Sendable {
    var startMinuteOfDay: Int
    var endMinuteOfDay: Int
    /// Explicit wind-down time; when nil we derive one (see `resolvedWindDownMinute`).
    var windDownMinuteOfDay: Int?
    /// Discretionary habit budget. Decoupled from the window length on purpose —
    /// the user (or, later, the AI) sets it directly.
    var budgetMinutes: Int
    var notificationsEnabled: Bool

    static let `default` = DayWindow(
        startMinuteOfDay: 7 * 60,
        endMinuteOfDay: 22 * 60,
        windDownMinuteOfDay: nil,
        budgetMinutes: 120,
        notificationsEnabled: false
    )

    /// Length of the active day in minutes (0 when the end isn't after the start).
    var lengthMinutes: Int { max(0, endMinuteOfDay - startMinuteOfDay) }

    /// The effective wind-down minute: the explicit value when set, otherwise one
    /// hour before the day's end (never earlier than the start). Phase 23's
    /// evening policy layers a sunset fallback on top of this.
    var resolvedWindDownMinute: Int {
        if let w = windDownMinuteOfDay { return Self.clampToDay(w) }
        return max(startMinuteOfDay, endMinuteOfDay - 60)
    }

    static func clampToDay(_ minute: Int) -> Int { min(max(minute, 0), 24 * 60 - 1) }
}

/// A daily local notification planned from the day window. Value, not nag —
/// capped at two per day (start + wind-down).
struct PlannedDayNotification: Equatable, Sendable {
    enum Kind: String, Sendable { case dayStart, windDown }
    let kind: Kind
    let minuteOfDay: Int
    let title: String
    let body: String

    var identifier: String { "willpower.daynotif.\(kind.rawValue)" }
}

/// Pure planner: turns a `DayWindow` into the (≤2) notifications to schedule.
/// Schedulability and OS calls live in `DayNotificationService`.
enum DayNotificationScheduler {
    static func plan(for window: DayWindow) -> [PlannedDayNotification] {
        guard window.notificationsEnabled else { return [] }
        return [
            PlannedDayNotification(
                kind: .dayStart,
                minuteOfDay: DayWindow.clampToDay(window.startMinuteOfDay),
                title: "A fresh day",
                body: "Pick the few habits that matter and budget your time."
            ),
            PlannedDayNotification(
                kind: .windDown,
                minuteOfDay: window.resolvedWindDownMinute,
                title: "Winding down",
                body: "Take a minute to reflect on how today went."
            )
        ]
    }

    /// Identifiers the planner can ever emit — used to clear stale requests.
    static var allIdentifiers: [String] {
        [PlannedDayNotification.Kind.dayStart, .windDown]
            .map { "willpower.daynotif.\($0.rawValue)" }
    }
}

/// UserDefaults-backed persistence for the day window (a device preference, like
/// the card background — not part of the synced data set).
struct DayWindowStore {
    private let defaults: UserDefaults
    private let key = "willpower.dayWindow.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var current: DayWindow {
        guard let data = defaults.data(forKey: key),
              let window = try? JSONDecoder().decode(DayWindow.self, from: data) else {
            return .default
        }
        return window
    }

    func save(_ window: DayWindow) {
        guard let data = try? JSONEncoder().encode(window) else { return }
        defaults.set(data, forKey: key)
    }
}
