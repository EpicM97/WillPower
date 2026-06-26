import XCTest
@testable import HabitTracker

@MainActor
final class ActiveHabitSessionTests: XCTestCase {
    func test_start_setsActiveHabit_andCallsController() async throws {
        let controller = MockLiveActivityController()
        let session = ActiveHabitSession(controller: controller)
        let habit = Habit(title: "Sprint", energy: .high, estimatedMinutes: 20)

        await session.start(habit: habit)

        XCTAssertTrue(session.isRunning)
        XCTAssertEqual(session.activeHabitID, habit.id)
        XCTAssertEqual(controller.calls.count, 1)
        if case .start(let state) = controller.calls.first {
            XCTAssertEqual(state.estimatedMinutes, 20)
            XCTAssertEqual(state.energyRaw, EnergyLevel.high.rawValue)
        } else {
            XCTFail("Expected start call")
        }
    }

    func test_start_whenAnotherRunning_recordsError() async throws {
        let controller = MockLiveActivityController()
        let session = ActiveHabitSession(controller: controller)
        await session.start(habit: Habit(title: "A"))

        await session.start(habit: Habit(title: "B"))

        XCTAssertNotNil(session.lastError)
        XCTAssertEqual(controller.calls.filter { if case .start = $0 { true } else { false } }.count, 1)
    }

    func test_stop_endsActivity_andClearsState() async throws {
        let controller = MockLiveActivityController()
        let session = ActiveHabitSession(controller: controller)
        await session.start(habit: Habit(title: "Run"))

        await session.stop()

        XCTAssertFalse(session.isRunning)
        XCTAssertNil(session.activeHabitID)
        XCTAssertNil(session.startedAt)
        XCTAssertTrue(controller.calls.contains { if case .end = $0 { true } else { false } })
    }

    func test_elapsedMinutes_usesInjectedClock() async throws {
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        var clock = baseDate
        let controller = MockLiveActivityController()
        let session = ActiveHabitSession(controller: controller, now: { clock })
        await session.start(habit: Habit(title: "Run"))

        clock = baseDate.addingTimeInterval(125)  // 2 min 5 sec
        XCTAssertEqual(session.elapsedMinutes(), 2)
    }

    func test_elapsedMinutes_capsAt8Hours() async throws {
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        var clock = baseDate
        let session = ActiveHabitSession(controller: MockLiveActivityController(), now: { clock })
        await session.start(habit: Habit(title: "Marathon"))

        clock = baseDate.addingTimeInterval(60 * 60 * 12) // 12 hours
        XCTAssertEqual(session.elapsedMinutes(), ActiveHabitSession.maxDurationMinutes)
    }

    func test_start_propagatesControllerErrorAsLastError() async throws {
        let controller = MockLiveActivityController()
        controller.errorOnStart = .notEnabled
        let session = ActiveHabitSession(controller: controller)

        await session.start(habit: Habit(title: "Run"))

        XCTAssertFalse(session.isRunning)
        XCTAssertNotNil(session.lastError)
    }
}
