import Foundation
import SwiftData

/// Applies a user-confirmed `IngestProposal` to the local store.
/// - Each proposed habit attaches to a project matched by case-insensitive
///   `project_hint`; falls back to the first non-deleted project.
/// - Milestones same matching logic; skipped if no project exists.
/// - Interruptions create a `DailySession(isInterruption: true)` for today.
@MainActor
enum IngestApplier {
    struct ApplyResult: Equatable {
        var habitsCreated: Int = 0
        var milestonesCreated: Int = 0
        var interruptionsCreated: Int = 0
        var skipped: [String] = []
    }

    static func apply(
        _ proposal: IngestProposal,
        accept: AcceptedSet,
        in context: ModelContext
    ) -> ApplyResult {
        var result = ApplyResult()
        let projects = (try? context.fetch(FetchDescriptor<Project>(
            predicate: #Predicate { $0.deletedAt == nil }
        ))) ?? []

        // Habits are now top-level; no project linkage.
        let allHabitsCount = (try? context.fetch(FetchDescriptor<Habit>(
            predicate: #Predicate { $0.deletedAt == nil }
        )).count) ?? 0
        var nextOrder = allHabitsCount
        for habit in proposal.habits where accept.habits.contains(habit.id) {
            let h = Habit(
                title: habit.title,
                energy: habit.energy,
                estimatedMinutes: habit.estimatedMinutes,
                order: nextOrder
            )
            context.insert(h)
            nextOrder += 1
            result.habitsCreated += 1
        }

        for ms in proposal.milestones where accept.milestones.contains(ms.id) {
            guard let project = matchProject(hint: ms.projectHint, in: projects) else {
                result.skipped.append("milestone '\(ms.title)' — no project to attach")
                continue
            }
            let m = Milestone(title: ms.title, order: project.milestones.count, project: project)
            context.insert(m)
            result.milestonesCreated += 1
        }

        for it in proposal.interruptions where accept.interruptions.contains(it.id) {
            let s = DailySession(
                baseMinutes: it.expectedMinutes,
                compressedMinutes: it.expectedMinutes,
                isInterruption: true,
                orderHint: -1,
                note: it.title
            )
            context.insert(s)
            result.interruptionsCreated += 1
        }

        try? context.save()
        return result
    }

    private static func matchProject(hint: String?, in projects: [Project]) -> Project? {
        guard let hint = hint?.lowercased(), !hint.isEmpty else { return projects.first }
        return projects.first { $0.title.lowercased().contains(hint) || hint.contains($0.title.lowercased()) }
            ?? projects.first
    }

    /// User's per-item accept/reject. All true by default in the UI.
    struct AcceptedSet: Equatable {
        var habits: Set<String> = []
        var milestones: Set<String> = []
        var interruptions: Set<String> = []
        static func all(from p: IngestProposal) -> AcceptedSet {
            AcceptedSet(
                habits: Set(p.habits.map(\.id)),
                milestones: Set(p.milestones.map(\.id)),
                interruptions: Set(p.interruptions.map(\.id))
            )
        }
    }
}
