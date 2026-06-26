import Foundation
import SwiftData

/// Seeds a sample OKR graph + standalone habits on first launch so the app
/// isn't empty. Idempotent: keyed off a UserDefaults flag, also short-circuits
/// if any objective already exists.
@MainActor
enum DemoSeeder {
    static let userDefaultsKey = "WillPower.didSeedDemo.v2"

    static func seedIfNeeded(container: ModelContainer, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: userDefaultsKey) else { return }
        let context = container.mainContext
        let existing = (try? context.fetch(FetchDescriptor<Objective>()))?.filter { $0.deletedAt == nil } ?? []
        guard existing.isEmpty else {
            defaults.set(true, forKey: userDefaultsKey)
            return
        }
        seed(into: context)
        defaults.set(true, forKey: userDefaultsKey)
    }

    /// Seeds without touching UserDefaults — used by the "Re-seed demo data"
    /// debug action in Profile/Settings.
    static func forceSeed(container: ModelContainer) {
        seed(into: container.mainContext)
    }

    /// Hard-wipes ALL local data (OKR graph, sessions, journals, habits) and
    /// re-seeds only the four standalone habits. Used by the "Reset to habits
    /// only" QA action so the Today tab starts at a clean 0/120 budget.
    static func resetToHabitsOnly(container: ModelContainer) {
        let context = container.mainContext
        deleteAll(DailySession.self, in: context)
        deleteAll(Journal.self, in: context)
        deleteAll(ProjectTask.self, in: context)
        deleteAll(Milestone.self, in: context)
        deleteAll(Project.self, in: context)
        deleteAll(KeyResult.self, in: context)
        deleteAll(Objective.self, in: context)
        deleteAll(Habit.self, in: context)
        seedHabits(into: context)
        try? context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        let items = (try? context.fetch(FetchDescriptor<T>())) ?? []
        for item in items { context.delete(item) }
    }

    private static func seed(into context: ModelContext) {
        // One objective with two KRs, each carrying a project with tasks + a milestone.
        let objective = Objective(
            title: "Ship WillPower v1",
            details: "Reach App Store with a working core loop",
            dueDate: Calendar.current.date(byAdding: .month, value: 2, to: .now)
        )
        context.insert(objective)

        let kr1 = KeyResult(title: "Beta with 20 daily users", metricUnit: "DAU", targetValue: 20, order: 0, objective: objective)
        context.insert(kr1)
        let kr2 = KeyResult(title: "Ship 5 polish PRs", metricUnit: "PRs", targetValue: 5, order: 1, objective: objective)
        context.insert(kr2)

        let pMVP = Project(title: "MVP polish", details: "App Review-blocking issues", order: 0, keyResult: kr1)
        context.insert(pMVP)
        context.insert(Milestone(title: "Pass App Review", order: 0, project: pMVP))
        for (i, t) in [("Wire up onboarding analytics", TaskStatus.todo, 45),
                       ("Fix iPad layout in DailyDeck", .doing, 30),
                       ("Polish empty states", .done, 20)].enumerated() {
            context.insert(ProjectTask(title: t.0, status: t.1, estimatedMinutes: t.2, order: i, project: pMVP))
        }

        let pGrowth = Project(title: "Reach 20 DAU", details: "Beta growth experiments", order: 0, keyResult: kr2)
        context.insert(pGrowth)
        context.insert(Milestone(title: "10 invites sent", order: 0, project: pGrowth))
        for (i, t) in [("Draft beta invite copy", TaskStatus.todo, 30),
                       ("Set up Mixpanel funnel", .todo, 60)].enumerated() {
            context.insert(ProjectTask(title: t.0, status: t.1, estimatedMinutes: t.2, order: i, project: pGrowth))
        }

        // Standalone habits — no project linkage.
        seedHabits(into: context)

        try? context.save()
    }

    private static func seedHabits(into context: ModelContext) {
        let habits: [(String, EnergyLevel, Int)] = [
            ("Deep work block", .high, 60),
            ("Morning workout", .high, 30),
            ("Newsletter triage", .mid, 20),
            ("Stretch before bed", .low, 10)
        ]
        for (index, h) in habits.enumerated() {
            context.insert(Habit(title: h.0, energy: h.1, estimatedMinutes: h.2, order: index))
        }
    }
}
