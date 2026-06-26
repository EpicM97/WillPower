import Foundation

/// Pure helper that turns completed `DailySession`s into a "consecutive days
/// with activity" streak ending today (or yesterday — grace day before
/// midnight has passed).
enum StreakCalculator {
    struct Stats: Equatable {
        var currentStreak: Int
        var totalMinutes: Int
    }

    static func compute(
        sessions: [DailySession],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Stats {
        let completed = sessions.filter {
            $0.deletedAt == nil && $0.status == .completed && ($0.actualMinutes ?? 0) > 0
        }
        let totalMinutes = completed.reduce(0) { $0 + ($1.actualMinutes ?? 0) }

        var activeDays = Set<Date>()
        for session in completed {
            activeDays.insert(calendar.startOfDay(for: session.date))
        }

        let todayStart = calendar.startOfDay(for: today)
        var cursor: Date
        if activeDays.contains(todayStart) {
            cursor = todayStart
        } else {
            cursor = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            if !activeDays.contains(cursor) {
                return Stats(currentStreak: 0, totalMinutes: totalMinutes)
            }
        }

        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return Stats(currentStreak: streak, totalMinutes: totalMinutes)
    }
}
