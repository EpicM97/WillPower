import XCTest
import SwiftData
@testable import HabitTracker

@MainActor
final class SoftDeleteSyncTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer { try AppSchema.inMemoryContainer() }

    private func habitDTO(id: UUID = UUID(), title: String, updatedAt: Date, deletedAt: Date? = nil) -> SyncDTO.Habit {
        SyncDTO.Habit(id: id, title: title, energyRaw: 1, estimatedMinutes: 30, order: 0, priority: 1, updatedAt: updatedAt, deletedAt: deletedAt)
    }

    func testRemoteTombstoneMarksLocalDeleted() async throws {
        let container = try makeContainer()
        let id = UUID()
        let local = Habit(id: id, title: "to-delete", updatedAt: Date(timeIntervalSince1970: 500))
        container.mainContext.insert(local)
        try container.mainContext.save()

        let service = MockSyncService()
        await service.setStubbedRemote(SyncDTO.Snapshot(habits: [
            habitDTO(id: id, title: "to-delete", updatedAt: Date(timeIntervalSince1970: 1000), deletedAt: Date(timeIntervalSince1970: 1000))
        ]))

        let coord = SyncCoordinator(container: container, service: service, cursor: InMemorySyncCursor())
        _ = try await coord.syncNow()

        let habits = try container.mainContext.fetch(FetchDescriptor<Habit>())
        XCTAssertEqual(habits.count, 1)
        XCTAssertNotNil(habits.first?.deletedAt)
    }

    func testNewRemoteTombstoneIsNotMaterialized() async throws {
        let container = try makeContainer()
        let service = MockSyncService()
        await service.setStubbedRemote(SyncDTO.Snapshot(habits: [
            habitDTO(title: "ghost", updatedAt: .now, deletedAt: .now)
        ]))
        let coord = SyncCoordinator(container: container, service: service, cursor: InMemorySyncCursor())
        _ = try await coord.syncNow()
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Habit>()).isEmpty)
    }

    func testProjectProgressIgnoresDeletedMilestones() {
        let project = Project(title: "P")
        let a = Milestone(title: "a", isCompleted: true, project: project)
        let b = Milestone(title: "b", isCompleted: false, project: project)
        let c = Milestone(title: "c", isCompleted: true, project: project)
        c.deletedAt = .now
        project.milestones = [a, b, c]
        XCTAssertEqual(project.totalMilestones, 2)
        XCTAssertEqual(project.completedMilestones, 1)
        XCTAssertEqual(project.progress, 0.5)
    }

    func testHabitMinutesLogged_onlyCountsCompletedSessions() {
        let today = Calendar.current.startOfDay(for: .now)
        let h = Habit(title: "X", estimatedMinutes: 60)
        let pending = DailySession(date: today, baseMinutes: 60, status: .pending, habit: h)
        let done = DailySession(date: today, baseMinutes: 60, actualMinutes: 45, status: .completed, habit: h)
        h.sessions = [pending, done]
        XCTAssertEqual(h.minutesLogged(on: today), 45)
    }
}
