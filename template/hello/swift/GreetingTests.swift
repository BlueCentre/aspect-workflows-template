import XCTest

@testable import Greeting

final class GreetingTests: XCTestCase {
    func testGreeting() {
        XCTAssertEqual(greeting(), "Hello, world!")
    }
}
