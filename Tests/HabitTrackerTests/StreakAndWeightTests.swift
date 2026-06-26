import XCTest
@testable import HabitTracker

@MainActor
final class StreakAndWeightTests: XCTestCase {
    private func day(_ offset: Int, from today: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -offset, to: today) ?? today
    }

    private func session(date: Date, minutes: Int) -> DailySession {
        DailySession(date: date, baseMinutes: minutes, actualMinutes: minutes, status: .completed)
    }

    func testStreak_emptyLogs_isZero() {
        XCTAssertEqual(StreakCalculator.compute(sessions: []).currentStreak, 0)
    }

    func testStreak_threeConsecutiveDays_isThree() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [
            session(date: today, minutes: 20),
            session(date: day(1, from: today), minutes: 30),
            session(date: day(2, from: today), minutes: 15)
        ]
        let stats = StreakCalculator.compute(sessions: sessions, today: today)
        XCTAssertEqual(stats.currentStreak, 3)
        XCTAssertEqual(stats.totalMinutes, 65)
    }

    func testStreak_gapBreaksTheChain() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [
            session(date: today, minutes: 10),
            session(date: day(2, from: today), minutes: 10)
        ]
        XCTAssertEqual(StreakCalculator.compute(sessions: sessions, today: today).currentStreak, 1)
    }

    func testStreak_yesterdayCountsAsGrace() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [session(date: day(1, from: today), minutes: 30)]
        XCTAssertEqual(StreakCalculator.compute(sessions: sessions, today: today).currentStreak, 1)
    }

    func testStreak_skipsDeletedAndZeroDurationSessions() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let zero = DailySession(date: today, baseMinutes: 30, actualMinutes: 0, status: .completed)
        let deleted = session(date: today, minutes: 30)
        deleted.deletedAt = .now
        XCTAssertEqual(StreakCalculator.compute(sessions: [zero, deleted], today: today).currentStreak, 0)
    }

}
