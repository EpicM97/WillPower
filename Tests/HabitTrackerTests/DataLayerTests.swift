import XCTest
import SwiftData
@testable import HabitTracker

@MainActor
final class DataLayerTests: XCTestCase {
    func testSchemaIncludesAllModels() throws {
        let container = try AppSchema.inMemoryContainer()
        let context = container.mainContext

        let objective = Objective(title: "Obj"); context.insert(objective)
        let kr = KeyResult(title: "KR", objective: objective); context.insert(kr)
        let project = Project(title: "P", keyResult: kr); context.insert(project)
        let milestone = Milestone(title: "M", project: project); context.insert(milestone)
        let task = ProjectTask(title: "T", project: project); context.insert(task)
        let habit = Habit(title: "H"); context.insert(habit)
        let session = DailySession(baseMinutes: 30, habit: habit); context.insert(session)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Objective>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<KeyResult>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Project>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Milestone>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProjectTask>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Habit>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailySession>()).count, 1)
    }

    func testHabitDeleteCascadesToSessions() throws {
        let container = try AppSchema.inMemoryContainer()
        let context = container.mainContext

        let habit = Habit(title: "H"); context.insert(habit)
        let s = DailySession(baseMinutes: 30, habit: habit); context.insert(s)
        try context.save()

        context.delete(habit)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<DailySession>()).isEmpty)
    }

    func testProjectDeleteCascadesToTasksAndMilestones() throws {
        let container = try AppSchema.inMemoryContainer()
        let context = container.mainContext

        let project = Project(title: "P"); context.insert(project)
        context.insert(ProjectTask(title: "T", project: project))
        context.insert(Milestone(title: "M", project: project))
        try context.save()

        context.delete(project)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<ProjectTask>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Milestone>()).isEmpty)
    }
}
