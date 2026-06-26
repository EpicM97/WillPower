import XCTest
@testable import HabitTracker

final class EnergyLevelTests: XCTestCase {
    func test_ordering_lowLessThanMidLessThanHigh() {
        XCTAssertLessThan(EnergyLevel.low, EnergyLevel.mid)
        XCTAssertLessThan(EnergyLevel.mid, EnergyLevel.high)
    }

    func test_rawValue_roundTrip() {
        for level in EnergyLevel.allCases {
            XCTAssertEqual(EnergyLevel(rawValue: level.rawValue), level)
        }
    }
}
