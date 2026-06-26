import Foundation
import SwiftData

/// Idempotent: at the start of any day, ensure every active habit has a
/// pending `DailySession` for that day. Already-existing sessions for the
/// day (any status) are left alone. The midnight rollover job (Phase 16)
/// will call this nightly; until then it runs on Today load.
@MainActor
enum SessionGenerator {
    static func generate(
        for day: Date = .now,
        in context: ModelContext,
        calendar: Calendar = .current
    ) {
        let startOfDay = calendar.startOfDay(for: day)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        guard let habits = try? context.fetch(FetchDescriptor<Habit>(
            predicate: #Predicate { $0.deletedAt == nil }
        )) else { return }

        let sessionsToday = (try? context.fetch(FetchDescriptor<DailySession>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < nextDay && $0.deletedAt == nil }
        ))) ?? []

        let coveredHabitIDs = Set(sessionsToday.compactMap { $0.habit?.id })

        for habit in habits where !coveredHabitIDs.contains(habit.id) {
            let session = DailySession(
                date: startOfDay,
                baseMinutes: habit.estimatedMinutes,
                orderHint: habit.order,
                habit: habit
            )
            context.insert(session)
        }
        try? context.save()
    }
}
