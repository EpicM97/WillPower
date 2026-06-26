import XCTest
@testable import HabitTracker

final class HelloWorldTests: XCTestCase {
    func test_greeting_returnsHelloWorld() {
        XCTAssertEqual(Greeter.greeting, "Hello, World")
    }
}
