import XCTest
import SwiftData
@testable import HabitTracker

@MainActor
final class IngestApplierTests: XCTestCase {
    private var container: ModelContainer!

    override func setUp() async throws {
        container = try AppSchema.inMemoryContainer()
    }

    private func makeContext() -> ModelContext { container.mainContext }

    private func proposal(
        habits: [IngestProposal.ProposedHabit] = [],
        milestones: [IngestProposal.ProposedMilestone] = [],
        interruptions: [IngestProposal.ProposedInterruption] = []
    ) -> IngestProposal {
        IngestProposal(habits: habits, milestones: milestones, interruptions: interruptions, rawInput: "test", modelNote: nil)
    }

    func test_apply_createsStandaloneHabit() throws {
        let context = makeContext()
        let prop = proposal(habits: [.init(title: "Long run", energy: .high, estimatedMinutes: 60, projectHint: nil)])
        let result = IngestApplier.apply(prop, accept: .all(from: prop), in: context)
        XCTAssertEqual(result.habitsCreated, 1)
        let habits = try context.fetch(FetchDescriptor<Habit>())
        XCTAssertEqual(habits.first?.title, "Long run")
    }

    func test_apply_skipsItemsNotInAcceptSet() throws {
        let context = makeContext()
        let prop = proposal(habits: [
            .init(title: "Keep", energy: .mid, estimatedMinutes: 20, projectHint: nil),
            .init(title: "Drop", energy: .low, estimatedMinutes: 10, projectHint: nil)
        ])
        var accept = IngestApplier.AcceptedSet.all(from: prop)
        accept.habits = [prop.habits[0].id]
        let result = IngestApplier.apply(prop, accept: accept, in: context)
        XCTAssertEqual(result.habitsCreated, 1)
        let habits = try context.fetch(FetchDescriptor<Habit>())
        XCTAssertEqual(habits.map(\.title), ["Keep"])
    }

    func test_apply_interruption_createsTodaySession() throws {
        let context = makeContext()
        let prop = proposal(interruptions: [.init(title: "Call X", expectedMinutes: 30)])
        let result = IngestApplier.apply(prop, accept: .all(from: prop), in: context)
        XCTAssertEqual(result.interruptionsCreated, 1)
        let sessions = try context.fetch(FetchDescriptor<DailySession>())
        XCTAssertEqual(sessions.first?.isInterruption, true)
        XCTAssertEqual(sessions.first?.note, "Call X")
    }
}
