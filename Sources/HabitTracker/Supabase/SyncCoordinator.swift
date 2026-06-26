import Foundation
import SwiftData

/// Orchestrates one sync round-trip:
/// 1. Pull everything updated server-side since `lastSyncAt`.
/// 2. Merge into SwiftData via LWW (`SyncMapping.remoteWins`).
/// 3. Push everything updated locally since `lastSyncAt`.
/// 4. Advance `lastSyncAt`.
/// v3: Only Habits / Sessions / Journals sync. The work hierarchy is local-only.
@MainActor
final class SyncCoordinator {
    private let container: ModelContainer
    private let service: any SyncService
    private let cursor: SyncCursor
    private let now: () -> Date

    init(
        container: ModelContainer,
        service: any SyncService,
        cursor: SyncCursor = UserDefaultsSyncCursor(),
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.service = service
        self.cursor = cursor
        self.now = now
    }

    @discardableResult
    func syncNow() async throws -> SyncStats {
        let context = container.mainContext
        let startCursor = cursor.lastSyncAt
        let started = now()

        // PULL
        let remote = try await service.pullChanges(since: startCursor)
        let pulled = remote.habits.count + remote.sessions.count + remote.journals.count
        try merge(remote, into: context)
        try context.save()

        // PUSH
        let local = collectLocal(updatedAfter: startCursor, from: context)
        let pushed = local.habits.count + local.sessions.count + local.journals.count
        if !local.isEmpty {
            try await service.pushChanges(local)
        }

        cursor.lastSyncAt = started
        return SyncStats(pulled: pulled, pushed: pushed, syncedAt: started)
    }

    // MARK: Pull merge

    private func merge(_ remote: SyncDTO.Snapshot, into context: ModelContext) throws {
        let habitIndex = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Habit>()).map { ($0.id, $0) })
        let sessionIndex = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<DailySession>()).map { ($0.id, $0) })
        let journalIndex = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Journal>()).map { ($0.id, $0) })

        for dto in remote.habits {
            if let existing = habitIndex[dto.id] {
                if SyncMapping.remoteWins(local: existing.updatedAt, remote: dto.updatedAt) {
                    existing.title = dto.title
                    existing.energyRaw = dto.energyRaw
                    existing.estimatedMinutes = dto.estimatedMinutes
                    existing.order = dto.order
                    existing.priority = dto.priority
                    existing.kindRaw = dto.kindRaw
                    existing.anchorMinuteOfDay = dto.anchorMinuteOfDay
                    existing.updatedAt = dto.updatedAt
                    existing.deletedAt = dto.deletedAt
                }
            } else if dto.deletedAt == nil {
                let h = Habit(
                    id: dto.id,
                    title: dto.title,
                    energy: EnergyLevel(rawValue: dto.energyRaw) ?? .mid,
                    estimatedMinutes: dto.estimatedMinutes,
                    order: dto.order,
                    priority: dto.priority,
                    kind: HabitKind(rawValue: dto.kindRaw) ?? .duration,
                    anchorMinuteOfDay: dto.anchorMinuteOfDay,
                    updatedAt: dto.updatedAt
                )
                context.insert(h)
            }
        }

        // Refresh habit index after potential inserts so sessions can link.
        let habitsAfter = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Habit>()).map { ($0.id, $0) })

        for dto in remote.sessions {
            let parent = dto.habitID.flatMap { habitsAfter[$0] }
            if let existing = sessionIndex[dto.id] {
                if SyncMapping.remoteWins(local: existing.updatedAt, remote: dto.updatedAt) {
                    existing.date = dto.date
                    existing.baseMinutes = dto.baseMinutes
                    existing.compressedMinutes = dto.compressedMinutes
                    existing.actualMinutes = dto.actualMinutes
                    existing.statusRaw = dto.status
                    existing.stoppedEarly = dto.stoppedEarly
                    existing.isInterruption = dto.isInterruption
                    existing.energyRaw = dto.energyRaw
                    existing.orderHint = dto.orderHint
                    existing.startedAt = dto.startedAt
                    existing.completedAt = dto.completedAt
                    existing.note = dto.note
                    existing.habit = parent
                    existing.updatedAt = dto.updatedAt
                    existing.deletedAt = dto.deletedAt
                }
            } else if dto.deletedAt == nil {
                let s = DailySession(
                    id: dto.id,
                    date: dto.date,
                    baseMinutes: dto.baseMinutes,
                    compressedMinutes: dto.compressedMinutes,
                    actualMinutes: dto.actualMinutes,
                    status: SessionStatus(rawValue: dto.status) ?? .pending,
                    stoppedEarly: dto.stoppedEarly,
                    isInterruption: dto.isInterruption,
                    energy: EnergyLevel(rawValue: dto.energyRaw) ?? .mid,
                    orderHint: dto.orderHint,
                    startedAt: dto.startedAt,
                    completedAt: dto.completedAt,
                    note: dto.note,
                    updatedAt: dto.updatedAt,
                    habit: parent
                )
                context.insert(s)
            }
        }

        for dto in remote.journals {
            if let existing = journalIndex[dto.id] {
                if SyncMapping.remoteWins(local: existing.updatedAt, remote: dto.updatedAt) {
                    existing.date = dto.date
                    existing.disciplineScore = dto.disciplineScore
                    existing.completedCount = dto.completedCount
                    existing.deferredCount = dto.deferredCount
                    existing.interruptionCount = dto.interruptionCount
                    existing.totalMinutes = dto.totalMinutes
                    existing.summaryNote = dto.summaryNote
                    existing.updatedAt = dto.updatedAt
                    existing.deletedAt = dto.deletedAt
                }
            } else if dto.deletedAt == nil {
                context.insert(Journal(
                    id: dto.id,
                    date: dto.date,
                    disciplineScore: dto.disciplineScore,
                    completedCount: dto.completedCount,
                    deferredCount: dto.deferredCount,
                    interruptionCount: dto.interruptionCount,
                    totalMinutes: dto.totalMinutes,
                    summaryNote: dto.summaryNote,
                    updatedAt: dto.updatedAt
                ))
            }
        }
    }

    // MARK: Push collect

    private func collectLocal(updatedAfter cursor: Date?, from context: ModelContext) -> SyncDTO.Snapshot {
        let threshold = cursor ?? .distantPast
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<DailySession>())) ?? []
        let journals = (try? context.fetch(FetchDescriptor<Journal>())) ?? []
        return SyncDTO.Snapshot(
            habits: habits.filter { $0.updatedAt > threshold }.map(SyncMapping.dto),
            sessions: sessions.filter { $0.updatedAt > threshold }.map(SyncMapping.dto),
            journals: journals.filter { $0.updatedAt > threshold }.map(SyncMapping.dto)
        )
    }

}

struct SyncStats: Equatable {
    let pulled: Int
    let pushed: Int
    let syncedAt: Date
}

protocol SyncCursor: AnyObject {
    var lastSyncAt: Date? { get set }
}

final class UserDefaultsSyncCursor: SyncCursor {
    private let key = "WillPower.lastSyncAt"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastSyncAt: Date? {
        get { defaults.object(forKey: key) as? Date }
        set {
            if let newValue { defaults.set(newValue, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
    }
}

final class InMemorySyncCursor: SyncCursor {
    var lastSyncAt: Date?
    init(_ initial: Date? = nil) { self.lastSyncAt = initial }
}
