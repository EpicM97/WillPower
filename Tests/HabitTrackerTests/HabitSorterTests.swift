import XCTest
@testable import HabitTracker

final class HabitSorterTests: XCTestCase {
    private func habit(_ title: String, _ energy: EnergyLevel, _ minutes: Int = 30) -> Habit {
        Habit(title: title, energy: energy, estimatedMinutes: minutes)
    }

    func test_sort_emptyInput_returnsEmpty() {
        XCTAssertEqual(HabitSorter.sort(habits: [], byMatch: .high), [])
    }

    func test_sort_matchingEnergyFirst() {
        let habits = [
            habit("Read", .low),
            habit("Sprint", .high),
            habit("Email", .mid)
        ]
        let sorted = HabitSorter.sort(habits: habits, byMatch: .high)
        XCTAssertEqual(sorted.map(\.title), ["Sprint", "Email", "Read"])
    }

    func test_sort_ties_breakByShorterDuration() {
        let habits = [
            habit("LongRun", .high, 60),
            habit("QuickSprint", .high, 10),
            habit("MidRun", .high, 30)
        ]
        let sorted = HabitSorter.sort(habits: habits, byMatch: .high)
        XCTAssertEqual(sorted.map(\.title), ["QuickSprint", "MidRun", "LongRun"])
    }

    func test_sort_distanceSymmetric_aroundMid() {
        let habits = [
            habit("HighA", .high, 20),
            habit("LowA", .low, 20),
            habit("MidA", .mid, 50)
        ]
        let sorted = HabitSorter.sort(habits: habits, byMatch: .mid)
        XCTAssertEqual(sorted.first?.title, "MidA")
        XCTAssertEqual(Set(sorted.dropFirst().map(\.title)), Set(["HighA", "LowA"]))
    }

    func test_filter_returnsOnlyExactMatches_preservingOrder() {
        let habits = [
            habit("A", .low),
            habit("B", .high),
            habit("C", .low),
            habit("D", .mid)
        ]
        let filtered = HabitSorter.filter(habits: habits, matching: .low)
        XCTAssertEqual(filtered.map(\.title), ["A", "C"])
    }

    func test_filter_noMatches_returnsEmpty() {
        let habits = [habit("A", .low), habit("B", .mid)]
        XCTAssertEqual(HabitSorter.filter(habits: habits, matching: .high), [])
    }
}
