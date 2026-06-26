import XCTest
@testable import HabitTracker

final class OnThisDaySelectorTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func journal(_ date: Date, deleted: Bool = false) -> Journal {
        let j = Journal(date: date, disciplineScore: 0.5)
        if deleted { j.deletedAt = .now }
        return j
    }

    func test_returnsSameMonthDay_priorYears_newestFirst() {
        let reference = date(2026, 6, 17)
        let lastYear = journal(date(2025, 6, 17))
        let twoYearsAgo = journal(date(2024, 6, 17))
        let differentDay = journal(date(2025, 6, 16))
        let thisYear = journal(date(2026, 6, 17))

        let result = OnThisDaySelector.onThisDay(
            reference: reference,
            journals: [twoYearsAgo, differentDay, thisYear, lastYear],
            calendar: cal
        )
        XCTAssertEqual(result.map(\.date), [lastYear.date, twoYearsAgo.date])
    }

    func test_excludesDeleted() {
        let reference = date(2026, 6, 17)
        let result = OnThisDaySelector.onThisDay(
            reference: reference,
            journals: [journal(date(2025, 6, 17), deleted: true)],
            calendar: cal
        )
        XCTAssertTrue(result.isEmpty)
    }

    func test_emptyWhenNoPriorYearMatch() {
        let reference = date(2026, 6, 17)
        let result = OnThisDaySelector.onThisDay(
            reference: reference,
            journals: [journal(date(2026, 6, 17)), journal(date(2025, 1, 1))],
            calendar: cal
        )
        XCTAssertTrue(result.isEmpty)
    }
}
