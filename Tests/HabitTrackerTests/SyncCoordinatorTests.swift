import XCTest
import SwiftData
@testable import HabitTracker

@MainActor
final class SyncCoordinatorTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try AppSchema.inMemoryContainer()
    }

    private func habitDTO(id: UUID = UUID(), title: String, updatedAt: Date) -> SyncDTO.Habit {
        SyncDTO.Habit(id: id, title: title, energyRaw: 1, estimatedMinutes: 30, order: 0, priority: 1, updatedAt: updatedAt, deletedAt: nil)
    }

    func testFirstSync_pullsRemoteIntoLocal() async throws {
        let container = try makeContainer()
        let service = MockSyncService()
        await service.setStubbedRemote(SyncDTO.Snapshot(habits: [
            habitDTO(title: "From server", updatedAt: Date(timeIntervalSince1970: 1000))
        ]))

        let coord = SyncCoordinator(container: container, service: service, cursor: InMemorySyncCursor())
        let stats = try await coord.syncNow()

        XCTAssertEqual(stats.pulled, 1)
        let habits = try container.mainContext.fetch(FetchDescriptor<Habit>())
        XCTAssertEqual(habits.count, 1)
        XCTAssertEqual(habits.first?.title, "From server")
    }

    func testPushSendsOnlyLocallyChangedRecords() async throws {
        let container = try makeContainer()
        let service = MockSyncService()
        let cursor = InMemorySyncCursor(Date(timeIntervalSince1970: 1000))

        let fresh = Habit(title: "fresh", updatedAt: Date(timeIntervalSince1970: 1500))
        container.mainContext.insert(fresh)
        let stale = Habit(title: "stale", updatedAt: Date(timeIntervalSince1970: 100))
        container.mainContext.insert(stale)
        try container.mainContext.save()

        let coord = SyncCoordinator(container: container, service: service, cursor: cursor)
        let stats = try await coord.syncNow()
        XCTAssertEqual(stats.pushed, 1)

        let calls = await service.calls
        guard case let .push(snapshot) = calls.last else {
            return XCTFail("expected push call")
        }
        XCTAssertEqual(snapshot.habits.map(\.title), ["fresh"])
    }

    func testRemoteWinsWhenNewer() async throws {
        let container = try makeContainer()
        let id = UUID()
        let local = Habit(id: id, title: "local", updatedAt: Date(timeIntervalSince1970: 500))
        container.mainContext.insert(local)
        try container.mainContext.save()

        let service = MockSyncService()
        await service.setStubbedRemote(SyncDTO.Snapshot(habits: [
            habitDTO(id: id, title: "remote-wins", updatedAt: Date(timeIntervalSince1970: 1000))
        ]))

        let coord = SyncCoordinator(container: container, service: service, cursor: InMemorySyncCursor())
        _ = try await coord.syncNow()

        let habits = try container.mainContext.fetch(FetchDescriptor<Habit>())
        XCTAssertEqual(habits.count, 1)
        XCTAssertEqual(habits.first?.title, "remote-wins")
    }

    func testLocalKeptWhenLocalIsNewer() async throws {
        let container = try makeContainer()
        let id = UUID()
        let local = Habit(id: id, title: "local-wins", updatedAt: Date(timeIntervalSince1970: 2000))
        container.mainContext.insert(local)
        try container.mainContext.save()

        let service = MockSyncService()
        await service.setStubbedRemote(SyncDTO.Snapshot(habits: [
            habitDTO(id: id, title: "stale-remote", updatedAt: Date(timeIntervalSince1970: 1000))
        ]))

        let coord = SyncCoordinator(container: container, service: service, cursor: InMemorySyncCursor())
        _ = try await coord.syncNow()

        let habits = try container.mainContext.fetch(FetchDescriptor<Habit>())
        XCTAssertEqual(habits.first?.title, "local-wins")
    }

    func testCursorAdvances() async throws {
        let container = try makeContainer()
        let service = MockSyncService()
        let cursor = InMemorySyncCursor()
        let coord = SyncCoordinator(container: container, service: service, cursor: cursor, now: { Date(timeIntervalSince1970: 9999) })
        _ = try await coord.syncNow()
        XCTAssertEqual(cursor.lastSyncAt, Date(timeIntervalSince1970: 9999))
    }
}
