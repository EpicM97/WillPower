import XCTest
@testable import HabitTracker

final class DayWindowTests: XCTestCase {
    func test_default_isSensible() {
        let w = DayWindow.default
        XCTAssertEqual(w.startMinuteOfDay, 7 * 60)
        XCTAssertEqual(w.endMinuteOfDay, 22 * 60)
        XCTAssertNil(w.windDownMinuteOfDay)
        XCTAssertEqual(w.budgetMinutes, 120)
        XCTAssertFalse(w.notificationsEnabled)
    }

    func test_lengthMinutes_guardsInvertedWindow() {
        XCTAssertEqual(DayWindow(startMinuteOfDay: 7 * 60, endMinuteOfDay: 22 * 60, windDownMinuteOfDay: nil, budgetMinutes: 120, notificationsEnabled: false).lengthMinutes, 15 * 60)
        XCTAssertEqual(DayWindow(startMinuteOfDay: 22 * 60, endMinuteOfDay: 7 * 60, windDownMinuteOfDay: nil, budgetMinutes: 120, notificationsEnabled: false).lengthMinutes, 0)
    }

    func test_resolvedWindDown_defaultsToOneHourBeforeEnd() {
        XCTAssertEqual(DayWindow.default.resolvedWindDownMinute, 21 * 60)
    }

    func test_resolvedWindDown_usesExplicitWhenSet() {
        var w = DayWindow.default
        w.windDownMinuteOfDay = 20 * 60 + 30
        XCTAssertEqual(w.resolvedWindDownMinute, 20 * 60 + 30)
    }

    func test_resolvedWindDown_neverBeforeStart() {
        let w = DayWindow(startMinuteOfDay: 9 * 60, endMinuteOfDay: 9 * 60 + 30, windDownMinuteOfDay: nil, budgetMinutes: 60, notificationsEnabled: false)
        XCTAssertEqual(w.resolvedWindDownMinute, 9 * 60) // end-60 would be before start
    }

    // MARK: Scheduler

    func test_scheduler_disabled_producesNothing() {
        XCTAssertTrue(DayNotificationScheduler.plan(for: .default).isEmpty)
    }

    func test_scheduler_enabled_producesStartAndWindDown() {
        var w = DayWindow.default
        w.notificationsEnabled = true
        let plan = DayNotificationScheduler.plan(for: w)
        XCTAssertEqual(plan.count, 2)
        XCTAssertEqual(plan[0].kind, .dayStart)
        XCTAssertEqual(plan[0].minuteOfDay, 7 * 60)
        XCTAssertEqual(plan[1].kind, .windDown)
        XCTAssertEqual(plan[1].minuteOfDay, 21 * 60)
        // Distinct identifiers so the OS doesn't collapse them.
        XCTAssertNotEqual(plan[0].identifier, plan[1].identifier)
    }

    // MARK: Store

    func test_store_roundTrips() {
        let defaults = UserDefaults(suiteName: "DayWindowTests-\(UUID())")!
        let store = DayWindowStore(defaults: defaults)
        XCTAssertEqual(store.current, .default, "absent key returns the default window")

        var w = DayWindow.default
        w.startMinuteOfDay = 6 * 60
        w.budgetMinutes = 200
        w.notificationsEnabled = true
        store.save(w)
        XCTAssertEqual(store.current, w)
    }
}
