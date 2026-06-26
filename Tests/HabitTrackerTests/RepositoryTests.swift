import XCTest
import SwiftData
@testable import HabitTracker

@MainActor
final class RepositoryTests: XCTestCase {
    private func makeRepo() throws -> SwiftDataRepository {
        SwiftDataRepository(container: try AppSchema.inMemoryContainer())
    }

    func test_addObjective_thenFetch_returnsIt() async throws {
        let repo = try makeRepo()
        try await repo.add(objective: Objective(title: "Ship v1"))
        let objs = try await repo.fetchObjectives()
        XCTAssertEqual(objs.map(\.title), ["Ship v1"])
    }

    func test_addNestedGraph_linksRelationships() async throws {
        let repo = try makeRepo()
        let obj = Objective(title: "Ship v1"); try await repo.add(objective: obj)
        let kr = KeyResult(title: "20 DAU"); try await repo.add(keyResult: kr, to: obj)
        let project = Project(title: "Polish"); try await repo.add(project: project, to: kr)
        try await repo.add(task: ProjectTask(title: "Wire analytics"), to: project)
        let habit = Habit(title: "Jog", energy: .high); try await repo.add(habit: habit)
        try await repo.add(session: DailySession(baseMinutes: 20, actualMinutes: 22, status: .completed, completedAt: .now, habit: habit))

        let objs = try await repo.fetchObjectives()
        let fetched = try XCTUnwrap(objs.first)
        XCTAssertEqual(fetched.keyResults.first?.projects.first?.title, "Polish")
        XCTAssertEqual(fetched.keyResults.first?.projects.first?.tasks.first?.title, "Wire analytics")

        let habits = try await repo.fetchAllHabits()
        XCTAssertEqual(habits.first?.energy, .high)
        XCTAssertEqual(habits.first?.sessions.first?.actualMinutes, 22)
    }

    func test_deleteObjective_softDeletes() async throws {
        let repo = try makeRepo()
        let obj = Objective(title: "Read"); try await repo.add(objective: obj)
        try await repo.delete(obj)
        let objs = try await repo.fetchObjectives()
        XCTAssertTrue(objs.isEmpty)
    }
}
