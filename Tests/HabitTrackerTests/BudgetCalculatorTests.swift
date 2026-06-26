import XCTest
@testable import HabitTracker

@MainActor
final class BudgetCalculatorTests: XCTestCase {
    private func session(compressed: Int, status: SessionStatus = .pending) -> DailySession {
        DailySession(baseMinutes: compressed, compressedMinutes: compressed, status: status)
    }

    func testEmpty_isZero() {
        let s = BudgetCalculator.summarize(availableMinutes: 120, sessions: [])
        XCTAssertEqual(s.scheduledMinutes, 0)
        XCTAssertEqual(s.remainingMinutes, 120)
        XCTAssertFalse(s.isOverBudget)
    }

    func testUnderBudget() {
        let s = BudgetCalculator.summarize(availableMinutes: 120, sessions: [session(compressed: 30), session(compressed: 45)])
        XCTAssertEqual(s.scheduledMinutes, 75)
        XCTAssertEqual(s.remainingMinutes, 45)
        XCTAssertFalse(s.isOverBudget)
    }

    func testOverBudget() {
        let s = BudgetCalculator.summarize(availableMinutes: 60, sessions: [session(compressed: 80)])
        XCTAssertTrue(s.isOverBudget)
        XCTAssertEqual(s.remainingMinutes, -20)
    }

    func testExcludesDeferred() {
        let s = BudgetCalculator.summarize(availableMinutes: 120, sessions: [
            session(compressed: 60),
            session(compressed: 30, status: .deferred)
        ])
        XCTAssertEqual(s.scheduledMinutes, 60)
    }
}
