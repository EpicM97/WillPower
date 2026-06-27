import Foundation
import SwiftData

@Observable @MainActor
final class ProfileViewModel {
    private(set) var streakDays: Int = 0
    private(set) var milestonesCompleted: Int = 0
    private(set) var todayHabitsCount: Int = 0
    private(set) var activeProjects: [Project] = []

    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func load() async {
        let context = container.mainContext
        let sessions = (try? context.fetch(FetchDescriptor<DailySession>())) ?? []
        streakDays = StreakCalculator.compute(sessions: sessions).currentStreak

        let milestones = (try? context.fetch(FetchDescriptor<Milestone>())) ?? []
        milestonesCompleted = milestones.filter { $0.deletedAt == nil && $0.isCompleted }.count

        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        todayHabitsCount = habits.filter { $0.deletedAt == nil }.count

        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        activeProjects = projects
            .filter { $0.deletedAt == nil }
            .sorted { $0.progress > $1.progress }
            .prefix(3)
            .map { $0 }
    }

}
