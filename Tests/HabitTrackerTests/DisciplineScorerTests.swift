import XCTest
@testable import HabitTracker

@MainActor
final class DisciplineScorerTests: XCTestCase {
    private func session(base: Int = 30, compressed: Int? = nil, actual: Int? = nil, status: SessionStatus = .pending, energy: EnergyLevel = .mid, isInterruption: Bool = false, date: Date = .now) -> DailySession {
        let h = isInterruption ? nil : Habit(title: "h", energy: energy, estimatedMinutes: base)
        return DailySession(date: date, baseMinutes: base, compressedMinutes: compressed ?? base, actualMinutes: actual, status: status, isInterruption: isInterruption, habit: h)
    }

    func test_completedHittingCompressed_isOne() {
        let s = session(compressed: 30, actual: 30, status: .completed)
        XCTAssertEqual(DisciplineScorer.score(for: s), 1.0)
    }

    func test_completedAt70PercentOfCompressed_isPointSeven() {
        let s = session(compressed: 30, actual: 21, status: .completed)
        XCTAssertEqual(DisciplineScorer.score(for: s), 0.7)
    }

    func test_completedShowedUpButBailed_isPointFive() {
        let s = session(compressed: 30, actual: 5, status: .completed)
        XCTAssertEqual(DisciplineScorer.score(for: s), 0.5)
    }

    func test_completedZeroActual_isZero() {
        let s = session(compressed: 30, actual: 0, status: .completed)
        XCTAssertEqual(DisciplineScorer.score(for: s), 0.0)
    }

    func test_pendingAtEOD_isZero_otherwiseNil() {
        let s = session(status: .pending)
        XCTAssertNil(DisciplineScorer.score(for: s, atEndOfDay: false))
        XCTAssertEqual(DisciplineScorer.score(for: s, atEndOfDay: true), 0.0)
    }

    func test_deferredExcluded() {
        let s = session(status: .deferred)
        XCTAssertNil(DisciplineScorer.score(for: s))
    }

    func test_interruptionExcluded() {
        let s = session(status: .completed, isInterruption: true)
        XCTAssertNil(DisciplineScorer.score(for: s))
    }

    func test_dayScore_weightedByEnergy() {
        // high-energy session perfect, low-energy session 0 → high wins.
        let high = session(compressed: 30, actual: 30, status: .completed, energy: .high)
        let low = session(compressed: 30, actual: 0, status: .completed, energy: .low)
        // weights: high=3, low=1. weighted = (1.0*3 + 0.0*1) / (3+1) = 0.75
        let score = DisciplineScorer.dayScore(sessions: [high, low], atEndOfDay: true) ?? 0
        XCTAssertEqual(score, 0.75, accuracy: 0.001)
    }

    func test_dayScore_emptyDay_isNil() {
        XCTAssertNil(DisciplineScorer.dayScore(sessions: []))
    }
}
