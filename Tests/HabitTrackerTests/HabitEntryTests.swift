import XCTest
import SwiftData
@testable import HabitTracker

/// Sprint 1 §1.1 — the new memory-vault habit model. `HabitEntry` is one
/// per-habit-per-day completion record (replaces the budget-shaped
/// `DailySession`). These specs land before the model exists (harness-first).
@MainActor
final class HabitEntryTests: XCTestCase {

    // MARK: - Habit reshape

    func test_habit_newFields_haveSensibleDefaults() {
        let h = Habit(title: "Read")
        XCTAssertEqual(h.type, .checkIn)
        XCTAssertNil(h.target)
        XCTAssertEqual(h.category, .health)
        XCTAssertTrue(h.routines.isEmpty)
        XCTAssertNil(h.archivedAt)
    }

    func test_habit_storesTypeCategoryRoutines() {
        let h = Habit(
            title: "Water",
            type: .count,
            target: 8,
            category: .lifestyle,
            routines: [.morning, .evening]
        )
        XCTAssertEqual(h.type, .count)
        XCTAssertEqual(h.target, 8)
        XCTAssertEqual(h.category, .lifestyle)
        XCTAssertEqual(Set(h.routines), [.morning, .evening])
    }

    // MARK: - Entry completion semantics

    func test_entry_checkIn_isCompleteWhenDone() {
        let h = Habit(title: "Meditate", type: .checkIn)
        let entry = HabitEntry(date: .now, habit: h)
        XCTAssertFalse(entry.isComplete, "fresh check-in entry is not complete")
        entry.done = true
        XCTAssertTrue(entry.isComplete)
    }

    func test_entry_count_isCompleteAtTarget() {
        let h = Habit(title: "Water", type: .count, target: 8)
        let entry = HabitEntry(date: .now, count: 7, habit: h)
        XCTAssertFalse(entry.isComplete, "7 of 8 is not complete")
        entry.count = 8
        XCTAssertTrue(entry.isComplete, "hit target")
        entry.count = 9
        XCTAssertTrue(entry.isComplete, "over target still complete")
    }

    // MARK: - Routine bucketing

    func test_routine_sortsByDefaultTimeOfDay() {
        let ordered = Routine.allCases.sorted { $0.defaultStartMinute < $1.defaultStartMinute }
        XCTAssertEqual(ordered, [.morning, .noon, .afternoon, .evening])
    }

    // MARK: - Persistence through the live SwiftData schema

    func test_schema_persistsAndFetchesEntry() throws {
        let container = try AppSchema.inMemoryContainer()
        let context = container.mainContext
        let h = Habit(title: "Stretch", type: .checkIn, routines: [.morning])
        context.insert(h)
        let entry = HabitEntry(date: Calendar.current.startOfDay(for: .now), done: true, habit: h)
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<HabitEntry>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.habit?.id, h.id)
        XCTAssertTrue(fetched.first?.isComplete ?? false)
    }
}
