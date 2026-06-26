import SwiftUI
import XCTest
@testable import HabitTracker

final class CardBackgroundTests: XCTestCase {
    // Every case must survive a JSON round-trip so the choice persists.
    func test_codableRoundTrip_allCases() throws {
        let cases: [CardBackground] = [
            .surface,
            .solid(hex: "#1E88E5"),
            .remote(path: "stock/zen-01.jpg"),
            .local(filename: "abc-123.jpg")
        ]
        for bg in cases {
            let data = try JSONEncoder().encode(bg)
            let decoded = try JSONDecoder().decode(CardBackground.self, from: data)
            XCTAssertEqual(decoded, bg)
        }
    }

    // 6-digit hex (with or without leading #) parses to the right components.
    func test_hexParsing_sixDigits() throws {
        let c = try XCTUnwrap(Color(hex: "#FF8800"))
        let rgb = c.rgbComponents
        XCTAssertEqual(rgb.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(rgb.g, 0.533, accuracy: 0.01)
        XCTAssertEqual(rgb.b, 0.0, accuracy: 0.01)
        XCTAssertNotNil(Color(hex: "00AAFF"), "leading # is optional")
    }

    func test_hexParsing_rejectsGarbage() {
        XCTAssertNil(Color(hex: "nope"))
        XCTAssertNil(Color(hex: "#12"))
    }

    // The store defaults to .surface and persists whatever it's given.
    func test_store_defaultsToSurfaceAndPersists() throws {
        let suite = "test.cardbg.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = CardBackgroundStore(defaults: defaults)
        XCTAssertEqual(store.current, .surface, "no saved choice → neutral surface")

        store.save(.solid(hex: "#222222"))
        XCTAssertEqual(CardBackgroundStore(defaults: defaults).current, .solid(hex: "#222222"))
    }
}
