import XCTest
@testable import HabitTracker

/// Sprint 1 §1.4 (streak half) — entry-based streaks. Per the agreed model,
/// habits are daily and a streak = consecutive calendar days (ending today or
/// the grace day) with a *complete* entry. Any missed day breaks it.
@MainActor
final class HabitStreakTests: XCTestCase {
    private let cal = Calendar.current

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: .now))!
    }

    private func entry(_ offset: Int, done: Bool = true, habit: Habit) -> HabitEntry {
        HabitEntry(date: day(offset), done: done, habit: habit)
    }

    func test_empty_isZero() {
        XCTAssertEqual(HabitStreak.current(entries: []), 0)
    }

    func test_todayOnly_isOne() {
        let h = Habit(title: "h", type: .checkIn)
        XCTAssertEqual(HabitStreak.current(entries: [entry(0, habit: h)]), 1)
    }

    func test_consecutiveDays_count() {
        let h = Habit(title: "h", type: .checkIn)
        let entries = [entry(0, habit: h), entry(-1, habit: h), entry(-2, habit: h)]
        XCTAssertEqual(HabitStreak.current(entries: entries), 3)
    }

    func test_gapBreaksStreak() {
        let h = Habit(title: "h", type: .checkIn)
        // today + 3 days ago, missing yesterday and 2-ago → streak is just today.
        let entries = [entry(0, habit: h), entry(-3, habit: h)]
        XCTAssertEqual(HabitStreak.current(entries: entries), 1)
    }

    func test_missedTodayButYesterday_graceKeepsStreak() {
        let h = Habit(title: "h", type: .checkIn)
        let entries = [entry(-1, habit: h), entry(-2, habit: h)]
        XCTAssertEqual(HabitStreak.current(entries: entries), 2, "yesterday is the grace anchor")
    }

    func test_incompleteEntriesDontCount() {
        let h = Habit(title: "h", type: .checkIn)
        // today logged but not done → not complete → no streak.
        XCTAssertEqual(HabitStreak.current(entries: [entry(0, done: false, habit: h)]), 0)
    }

    func test_countHabit_belowTargetDoesNotCount() {
        let h = Habit(title: "Water", type: .count, target: 8)
        let short = HabitEntry(date: day(0), count: 3, habit: h)
        XCTAssertEqual(HabitStreak.current(entries: [short]), 0)
    }
}
