import XCTest
@testable import HabitTracker

@MainActor
final class MockRepositoryTests: XCTestCase {
    func test_addAndFetchObjective_roundTrips() async throws {
        let repo = MockRepository()
        try await repo.add(objective: Objective(title: "Read more"))
        let objs = try await repo.fetchObjectives()
        XCTAssertEqual(objs.map(\.title), ["Read more"])
    }

    func test_nestedGraph_buildsRelationshipsWithoutSwiftData() async throws {
        let repo = MockRepository()
        let obj = Objective(title: "Ship"); try await repo.add(objective: obj)
        let kr = KeyResult(title: "20 DAU"); try await repo.add(keyResult: kr, to: obj)
        let project = Project(title: "Polish"); try await repo.add(project: project, to: kr)
        try await repo.add(task: ProjectTask(title: "Wire analytics"), to: project)
        let habit = Habit(title: "Jog", energy: .high); try await repo.add(habit: habit)
        try await repo.add(session: DailySession(baseMinutes: 20, actualMinutes: 18, status: .completed, habit: habit))

        XCTAssertEqual(obj.keyResults.count, 1)
        XCTAssertIdentical(kr.objective, obj)
        XCTAssertIdentical(project.keyResult, kr)
        XCTAssertEqual(project.tasks.first?.title, "Wire analytics")
        XCTAssertEqual(habit.sessions.first?.actualMinutes, 18)
    }

    func test_deleteProject_softDeletesAndHidesFromFetch() async throws {
        let repo = MockRepository()
        let obj = Objective(title: "Ship"); try await repo.add(objective: obj)
        let kr = KeyResult(title: "KR"); try await repo.add(keyResult: kr, to: obj)
        let project = Project(title: "P"); try await repo.add(project: project, to: kr)
        try await repo.delete(project)
        XCTAssertNotNil(project.deletedAt)
        let active = try await repo.fetchProjects(in: kr)
        XCTAssertTrue(active.isEmpty)
    }

    func test_errorInjection_propagatesAndConsumesOnce() async throws {
        let repo = MockRepository()
        repo.errorOnNextWrite = .persistenceFailure("boom")
        do {
            try await repo.add(objective: Objective(title: "x"))
            XCTFail("Expected throw")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .persistenceFailure("boom"))
        }
        try await repo.add(objective: Objective(title: "y"))
        let objs = try await repo.fetchObjectives()
        XCTAssertEqual(objs.map(\.title), ["y"])
    }
}
