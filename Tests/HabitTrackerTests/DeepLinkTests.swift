import XCTest
@testable import HabitTracker

final class DeepLinkTests: XCTestCase {
    func testParsesHabitURL() {
        let id = UUID()
        let url = URL(string: "willpower://habit/\(id.uuidString)")!
        XCTAssertEqual(DeepLink.from(url), .habit(id))
    }

    func testRejectsWrongScheme() {
        let url = URL(string: "https://example.com/habit/\(UUID().uuidString)")!
        XCTAssertNil(DeepLink.from(url))
    }

    func testRejectsMalformedID() {
        let url = URL(string: "willpower://habit/not-a-uuid")!
        XCTAssertNil(DeepLink.from(url))
    }

    func testRoundTrip() {
        let link = DeepLink.habit(UUID())
        XCTAssertEqual(DeepLink.from(link.url), link)
    }
}
