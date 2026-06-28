import Foundation
import SwiftData

/// One per-habit, per-day completion record — the memory-vault replacement for
/// the budget-shaped `DailySession`. A `.checkIn` habit's day is complete when
/// `done`; a `.count` habit's when `count` reaches the habit's `target`. Created
/// lazily the first time the user interacts with the habit on a given day.
@Model
final class HabitEntry {
    @Attribute(.unique) var id: UUID

    /// Start-of-day this entry belongs to. Scopes "today" and powers recall.
    var date: Date
    var done: Bool
    var count: Int
    var note: String? = nil

    var createdAt: Date
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date? = nil

    var habit: Habit? = nil

    init(
        id: UUID = UUID(),
        date: Date = Calendar.current.startOfDay(for: .now),
        done: Bool = false,
        count: Int = 0,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        habit: Habit? = nil
    ) {
        self.id = id
        self.date = date
        self.done = done
        self.count = count
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.habit = habit
    }

    /// Whether this entry counts as a completed day for its habit's type.
    var isComplete: Bool {
        switch habit?.type ?? .checkIn {
        case .checkIn: return done
        case .count: return count >= max(1, habit?.target ?? 1)
        }
    }
}
