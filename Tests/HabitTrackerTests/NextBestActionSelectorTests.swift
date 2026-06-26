import XCTest
@testable import HabitTracker

@MainActor
final class NextBestActionSelectorTests: XCTestCase {
    func testReturnsNilWhenEmpty() {
        XCTAssertNil(NextBestActionSelector.pick(from: []))
    }

    func testInterruptionWins() {
        let h = Habit(title: "Deep", energy: .high)
        let normal = DailySession(baseMinutes: 60, orderHint: 0, habit: h)
        let interruption = DailySession(baseMinutes: 15, isInterruption: true, orderHint: 99)
        let pick = NextBestActionSelector.pick(from: [normal, interruption])
        XCTAssertTrue(pick?.isInterruption == true)
    }

    func testHighPriorityWinsAmongPending() {
        let highHabit = Habit(title: "Deep", energy: .high, priority: 2)
        let lowHabit = Habit(title: "Email", energy: .low, priority: 0)
        let high = DailySession(baseMinutes: 60, orderHint: 1, habit: highHabit)
        let low = DailySession(baseMinutes: 15, orderHint: 0, habit: lowHabit)
        let pick = NextBestActionSelector.pick(from: [low, high])
        XCTAssertEqual(pick?.habit?.title, "Deep")
    }

    func testSkipsCompletedSessions() {
        let h = Habit(title: "A", energy: .mid)
        let done = DailySession(baseMinutes: 30, status: .completed, habit: h)
        let pending = DailySession(baseMinutes: 30, orderHint: 1, habit: Habit(title: "B"))
        let pick = NextBestActionSelector.pick(from: [done, pending])
        XCTAssertEqual(pick?.habit?.title, "B")
    }
}
