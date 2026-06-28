import Foundation

/// Per-habit streak over its `HabitEntry` history. Per the agreed MVP model,
/// habits are daily and a streak = consecutive calendar days (ending today, or
/// yesterday as a grace anchor before midnight has passed) with a *complete*
/// entry. Any fully-missed day breaks it. Weekday scheduling is a later concern.
enum HabitStreak {
    static func current(
        entries: [HabitEntry],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let completeDays = Set(
            entries
                .filter { $0.deletedAt == nil && $0.isComplete }
                .map { calendar.startOfDay(for: $0.date) }
        )

        let todayStart = calendar.startOfDay(for: today)
        var cursor: Date
        if completeDays.contains(todayStart) {
            cursor = todayStart
        } else {
            cursor = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            if !completeDays.contains(cursor) { return 0 }
        }

        var streak = 0
        while completeDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
