import XCTest
import SwiftUI
@testable import AmgiTheme

final class AppFontTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(AppFont.system.rawValue, "system")
        XCTAssertEqual(AppFont.serif.rawValue, "serif")
    }

    func testAllCases() {
        XCTAssertEqual(AppFont.allCases, [.system, .serif])
    }

    func testEnvironmentDefault() {
        let env = EnvironmentValues()
        XCTAssertEqual(env.appFont, .system)
    }
}
