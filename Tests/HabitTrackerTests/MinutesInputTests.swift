import XCTest
@testable import HabitTracker

/// Numeric-only minutes entry shared by the duration fields (Inject / editor).
final class MinutesInputTests: XCTestCase {
    func test_sanitize_stripsNonDigits() {
        XCTAssertEqual(MinutesInput.sanitize("12a3"), "123")
        XCTAssertEqual(MinutesInput.sanitize("abc"), "")
        XCTAssertEqual(MinutesInput.sanitize("4 5 min"), "45")
    }

    func test_sanitize_capsToThreeDigits() {
        XCTAssertEqual(MinutesInput.sanitize("99999"), "999")
    }

    func test_minutes_parsesAndClampsToMax() {
        XCTAssertEqual(MinutesInput.minutes(from: "30"), 30)
        XCTAssertEqual(MinutesInput.minutes(from: "999"), 600)
    }

    func test_clamped_boundsIntToRange() {
        XCTAssertEqual(MinutesInput.clamped(0), 1)
        XCTAssertEqual(MinutesInput.clamped(-5), 1)
        XCTAssertEqual(MinutesInput.clamped(700), 600)
        XCTAssertEqual(MinutesInput.clamped(45), 45)
    }

    // reconcile: when the authoritative value changes, decide what the editable
    // text should show — nil means "leave the in-progress edit alone".
    func test_reconcile_leavesTextWhenItAlreadyRepresentsValue() {
        XCTAssertNil(MinutesInput.reconcile(text: "30", value: 30))
        // Empty field parses to the fallback (15); if value is also 15, don't
        // clobber the user's in-progress clear.
        XCTAssertNil(MinutesInput.reconcile(text: "", value: 15))
    }

    func test_reconcile_rewritesTextWhenValueDivergeFromText() {
        // Stepper drove the value while the field was empty.
        XCTAssertEqual(MinutesInput.reconcile(text: "", value: 14), "14")
        // Stepper +1 from a typed value.
        XCTAssertEqual(MinutesInput.reconcile(text: "30", value: 31), "31")
    }

    func test_minutes_emptyZeroOrGarbageFallsBackNeverTwo() {
        XCTAssertEqual(MinutesInput.minutes(from: ""), MinutesInput.fallback)
        XCTAssertEqual(MinutesInput.minutes(from: "0"), MinutesInput.fallback)
        XCTAssertEqual(MinutesInput.minutes(from: "abc"), MinutesInput.fallback)
        XCTAssertEqual(MinutesInput.fallback, 15)
    }
}
