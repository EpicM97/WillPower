import Foundation

/// Pure mappers between SwiftData `@Model` types and `SyncDTO` wire structs.
/// Kept separate from the models so we can unit-test conversions without
/// spinning up a ModelContainer.
enum SyncMapping {
    static func dto(from habit: Habit) -> SyncDTO.Habit {
        SyncDTO.Habit(
            id: habit.id,
            title: habit.title,
            energyRaw: habit.energyRaw,
            estimatedMinutes: habit.estimatedMinutes,
            order: habit.order,
            priority: habit.priority,
            kindRaw: habit.kindRaw,
            anchorMinuteOfDay: habit.anchorMinuteOfDay,
            updatedAt: habit.updatedAt,
            deletedAt: habit.deletedAt
        )
    }

    static func dto(from session: DailySession) -> SyncDTO.DailySession {
        SyncDTO.DailySession(
            id: session.id,
            habitID: session.habit?.id,
            date: session.date,
            baseMinutes: session.baseMinutes,
            compressedMinutes: session.compressedMinutes,
            actualMinutes: session.actualMinutes,
            status: session.statusRaw,
            stoppedEarly: session.stoppedEarly,
            isInterruption: session.isInterruption,
            energyRaw: session.energyRaw,
            orderHint: session.orderHint,
            startedAt: session.startedAt,
            completedAt: session.completedAt,
            note: session.note,
            updatedAt: session.updatedAt,
            deletedAt: session.deletedAt
        )
    }

    static func dto(from journal: Journal) -> SyncDTO.Journal {
        SyncDTO.Journal(
            id: journal.id,
            date: journal.date,
            disciplineScore: journal.disciplineScore,
            completedCount: journal.completedCount,
            deferredCount: journal.deferredCount,
            interruptionCount: journal.interruptionCount,
            totalMinutes: journal.totalMinutes,
            summaryNote: journal.summaryNote,
            updatedAt: journal.updatedAt,
            deletedAt: journal.deletedAt
        )
    }

    /// Returns `true` iff `remote.updatedAt > local.updatedAt`. Used by the
    /// coordinator to decide whether to overwrite local state with remote.
    static func remoteWins(local: Date, remote: Date) -> Bool {
        remote > local
    }
}
