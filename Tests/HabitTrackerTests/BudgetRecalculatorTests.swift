import XCTest
@testable import HabitTracker

@MainActor
final class BudgetRecalculatorTests: XCTestCase {
    private func session(base: Int, priority: Int = 1, status: SessionStatus = .pending, isInterruption: Bool = false, actual: Int? = nil, kind: HabitKind = .duration) -> DailySession {
        let h = Habit(title: "h", energy: .mid, estimatedMinutes: base, priority: priority, kind: kind)
        return DailySession(baseMinutes: base, compressedMinutes: base, actualMinutes: actual, status: status, isInterruption: isInterruption, habit: isInterruption ? nil : h)
    }

    // Moment habits (~0 min checkboxes) are never compressed, even at a tiny budget.
    func test_momentHabit_neverCompressed() {
        let moment = session(base: 2, kind: .moment)
        let duration = session(base: 60, kind: .duration)
        BudgetRecalculator.recompute(sessions: [moment, duration], availableMinutes: 10)
        XCTAssertEqual(moment.compressedMinutes, 2)
    }

    // Anchored habits reserve their minutes (shrinking the duration pool) and are
    // themselves left uncompressed.
    func test_anchoredHabit_reservesMinutesAndIsNotCompressed() {
        let anchored = session(base: 30, kind: .anchored)
        let duration = session(base: 60, kind: .duration)
        // available 60; anchored reserves 30 → duration pool 30 → 60 scales to 30.
        BudgetRecalculator.recompute(sessions: [anchored, duration], availableMinutes: 60)
        XCTAssertEqual(anchored.compressedMinutes, 30)
        XCTAssertEqual(duration.compressedMinutes, 30)
    }

    func test_underBudget_restoresBase() {
        let a = session(base: 30); let b = session(base: 45)
        a.compressedMinutes = 10; b.compressedMinutes = 20 // pretend previously compressed
        BudgetRecalculator.recompute(sessions: [a, b], availableMinutes: 120)
        XCTAssertEqual(a.compressedMinutes, 30)
        XCTAssertEqual(b.compressedMinutes, 45)
    }

    func test_overBudget_shrinksProportionally() {
        let a = session(base: 60)  // 60/90 of 60 budget = 40
        let b = session(base: 30)  // 30/90 of 60 budget = 20
        BudgetRecalculator.recompute(sessions: [a, b], availableMinutes: 60)
        XCTAssertEqual(a.compressedMinutes, 40)
        XCTAssertEqual(b.compressedMinutes, 20)
    }

    func test_respectsMinimumFloor() {
        // base 60 → floor max(5, ceil(60*0.3)) = 18
        // budget 20 ≥ floor → compressed = floor (proportional would round to 20).
        let a = session(base: 60)
        BudgetRecalculator.recompute(sessions: [a], availableMinutes: 20)
        XCTAssertEqual(a.compressedMinutes, 20)
        XCTAssertEqual(a.status, .pending)
    }

    func test_belowFloor_shrinksToFloorNeverDefers() {
        // base 60 floor=18, budget 10 < 18 → clamp to floor, stay pending.
        // Habits are never deferred.
        let a = session(base: 60)
        BudgetRecalculator.recompute(sessions: [a], availableMinutes: 10)
        XCTAssertEqual(a.compressedMinutes, 18)
        XCTAssertEqual(a.status, .pending)
    }

    func test_interruptionConsumesBudgetAndShrinksPending() {
        let interruption = session(base: 60, isInterruption: true)
        let pending = session(base: 60)
        BudgetRecalculator.recompute(sessions: [interruption, pending], availableMinutes: 120)
        XCTAssertEqual(pending.compressedMinutes, 60) // 120 - 60 = 60 left, fits base
    }

    func test_completedSubtractsActual_notCompressed() {
        let done = session(base: 60, status: .completed, actual: 30)
        let pending = session(base: 60)
        BudgetRecalculator.recompute(sessions: [done, pending], availableMinutes: 120)
        XCTAssertEqual(pending.compressedMinutes, 60) // 120 - 30 = 90, pending base fits
    }

    func test_floorsExceedBudget_allShrinkToFloorNoneDeferred() {
        let low = session(base: 60, priority: 0)
        let high = session(base: 60, priority: 2)
        // floors = 18 + 18 = 36; budget 20 < 36 → both clamp to floor, none bumped.
        BudgetRecalculator.recompute(sessions: [low, high], availableMinutes: 20)
        XCTAssertEqual(low.compressedMinutes, 18)
        XCTAssertEqual(high.compressedMinutes, 18)
        XCTAssertEqual(low.status, .pending)
        XCTAssertEqual(high.status, .pending)
    }
}
