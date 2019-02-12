import XCTest
@testable import PerfectNIOCompat

final class PerfectNIOCompatTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(PerfectNIOCompat().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
