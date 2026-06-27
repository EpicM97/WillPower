import Foundation
import SwiftData

/// Phase 15/16: snapshots a day's sessions into a `Journal` row and regenerates
/// tomorrow's sessions from the habit templates. Idempotent per date — running
/// twice for the same `day` updates the existing journal rather than dup'ing.
@MainActor
enum JournalArchiver {
    @discardableResult
    static func archive(
        day: Date = .now,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> Journal? {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        let sessions = (try? context.fetch(FetchDescriptor<DailySession>(
            predicate: #Predicate {
                $0.date >= start && $0.date < end && $0.deletedAt == nil
            }
        ))) ?? []
        guard !sessions.isEmpty else { return nil }

        // Discipline scoring removed in the pivot; the field is retained for
        // sync compatibility and stays 0 until stats are redesigned (EPIC-5).
        let score = 0.0
        let completed = sessions.filter { $0.status == .completed && !$0.isInterruption }.count
        let deferred = sessions.filter { $0.status == .deferred }.count
        let interruptions = sessions.filter { $0.isInterruption }.count
        let totalMinutes = sessions.reduce(0) { $0 + ($1.actualMinutes ?? 0) }

        let existing = (try? context.fetch(FetchDescriptor<Journal>(
            predicate: #Predicate { $0.date == start }
        )))?.first

        let journal: Journal
        if let existing {
            existing.disciplineScore = score
            existing.completedCount = completed
            existing.deferredCount = deferred
            existing.interruptionCount = interruptions
            existing.totalMinutes = totalMinutes
            existing.updatedAt = .now
            journal = existing
        } else {
            journal = Journal(
                date: start,
                disciplineScore: score,
                completedCount: completed,
                deferredCount: deferred,
                interruptionCount: interruptions,
                totalMinutes: totalMinutes
            )
            context.insert(journal)
        }
        try? context.save()
        return journal
    }

    /// Convenience: archive today, then materialize tomorrow's sessions from
    /// active habit templates. Called on midnight rollover (when wired) and
    /// from the manual "Run end-of-day archival" Settings button.
    static func rollover(now: Date = .now, in context: ModelContext) {
        archive(day: now, in: context)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        SessionGenerator.generate(for: tomorrow, in: context)
    }
}
