import XCTest
@testable import AmgiTheme

final class ThemeTests: XCTestCase {
    func testThemeRawValues() {
        XCTAssertEqual(Theme.vivid.rawValue, "vivid")
        XCTAssertEqual(Theme.muted.rawValue, "muted")
    }

    func testThemeAllCases() {
        XCTAssertEqual(Theme.allCases, [.vivid, .muted])
    }

    func testAppearanceRawValues() {
        XCTAssertEqual(Appearance.system.rawValue, "system")
        XCTAssertEqual(Appearance.light.rawValue, "light")
        XCTAssertEqual(Appearance.dark.rawValue, "dark")
    }

    func testAppearanceAllCases() {
        XCTAssertEqual(Appearance.allCases, [.system, .light, .dark])
    }
}
