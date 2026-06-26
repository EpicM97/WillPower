import XCTest
@testable import HabitTracker

final class EveningPromptPolicyTests: XCTestCase {
    // Wind-down trigger — fires regardless of outcome.
    func test_atOrAfterWindDown_surfaces_evenWithWorkLeft() {
        XCTAssertTrue(EveningPromptPolicy.shouldSurface(nowMinute: 21 * 60, windDownMinute: 21 * 60, resolvedCount: 0, unresolvedCount: 3))
        XCTAssertTrue(EveningPromptPolicy.shouldSurface(nowMinute: 22 * 60, windDownMinute: 21 * 60, resolvedCount: 5, unresolvedCount: 0))
    }

    func test_beforeWindDown_withWorkLeft_doesNotSurface() {
        XCTAssertFalse(EveningPromptPolicy.shouldSurface(nowMinute: 14 * 60, windDownMinute: 21 * 60, resolvedCount: 2, unresolvedCount: 1))
    }

    // Early opportunistic trigger — everything resolved before wind-down.
    func test_allResolvedEarly_surfaces() {
        XCTAssertTrue(EveningPromptPolicy.shouldSurface(nowMinute: 15 * 60, windDownMinute: 21 * 60, resolvedCount: 3, unresolvedCount: 0))
    }

    // Vacuous truth guard — a fresh day with nothing done must not surface early.
    func test_nothingResolvedAndNothingLeft_doesNotSurfaceEarly() {
        XCTAssertFalse(EveningPromptPolicy.shouldSurface(nowMinute: 9 * 60, windDownMinute: 21 * 60, resolvedCount: 0, unresolvedCount: 0))
    }
}
