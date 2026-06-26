import Foundation
import SwiftData

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var title: String
    var energyRaw: Int
    var estimatedMinutes: Int
    var order: Int
    /// 0 = low, 1 = mid, 2 = high. Mirrors `energy` by default but can be
    /// edited independently. Drives compression's deferral order (lowest first).
    var priority: Int = 1
    /// Time-shape of the habit (duration / moment / anchored). Defaults to
    /// duration so existing budget math is unchanged. See `HabitKind`.
    var kindRaw: Int = HabitKind.duration.rawValue
    /// For `.anchored` habits: the clock time (minutes from midnight) the block
    /// is pinned to. nil for non-anchored habits (and legacy rows).
    var anchorMinuteOfDay: Int? = nil
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \DailySession.habit)
    var sessions: [DailySession]

    init(
        id: UUID = UUID(),
        title: String,
        energy: EnergyLevel = .mid,
        estimatedMinutes: Int = 30,
        order: Int = 0,
        priority: Int? = nil,
        kind: HabitKind = .duration,
        anchorMinuteOfDay: Int? = nil,
        updatedAt: Date = .now,
        sessions: [DailySession] = []
    ) {
        self.id = id
        self.title = title
        self.energyRaw = energy.rawValue
        self.estimatedMinutes = estimatedMinutes
        self.order = order
        self.priority = priority ?? energy.rawValue
        self.kindRaw = kind.rawValue
        self.anchorMinuteOfDay = anchorMinuteOfDay
        self.updatedAt = updatedAt
        self.sessions = sessions
    }

    var energy: EnergyLevel {
        get { EnergyLevel(rawValue: energyRaw) ?? .mid }
        set { energyRaw = newValue.rawValue }
    }

    var kind: HabitKind {
        get { HabitKind(rawValue: kindRaw) ?? .duration }
        set { kindRaw = newValue.rawValue }
    }

    /// Minutes actually logged across this habit's completed sessions on `day`.
    func minutesLogged(on day: Date, calendar: Calendar = .current) -> Int {
        sessions.reduce(0) { sum, s in
            guard s.deletedAt == nil,
                  s.status == .completed,
                  calendar.isDate(s.date, inSameDayAs: day) else { return sum }
            return sum + (s.actualMinutes ?? 0)
        }
    }
}
