import XCTest
@testable import AmgiTheme

final class ThemeTests: XCTestCase {
    func testThemeIDRawValues() {
        XCTAssertEqual(ThemeID.vivid.rawValue, "vivid")
        XCTAssertEqual(ThemeID.muted.rawValue, "muted")
        XCTAssertEqual(ThemeID.sepia.rawValue, "sepia")
    }

    func testThemeIDRawInit() {
        XCTAssertEqual(ThemeID(rawValue: "vivid"), .vivid)
        XCTAssertEqual(ThemeID(rawValue: "unknown").rawValue, "unknown")
    }

    func testThemeIDEquatable() {
        XCTAssertEqual(ThemeID.vivid, ThemeID(rawValue: "vivid"))
        XCTAssertNotEqual(ThemeID.vivid, ThemeID.muted)
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
