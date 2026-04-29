import XCTest
import SwiftUI
@testable import AmgiTheme

final class ThemeManagerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test-suite-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultValuesOnEmptyStore() {
        let manager = ThemeManager(defaults: defaults)
        XCTAssertEqual(manager.theme, .vivid)
        XCTAssertEqual(manager.appearance, .system)
    }

    func testSettingThemePersistsAcrossInstances() {
        let m1 = ThemeManager(defaults: defaults)
        m1.theme = .muted
        m1.appearance = .dark

        let m2 = ThemeManager(defaults: defaults)
        XCTAssertEqual(m2.theme, .muted)
        XCTAssertEqual(m2.appearance, .dark)
    }

    func testInvalidStoredValueFallsBackToDefault() {
        defaults.set("garbage", forKey: "theme.selection")
        defaults.set("nonsense", forKey: "theme.appearance")

        let manager = ThemeManager(defaults: defaults)
        XCTAssertEqual(manager.theme, .vivid)
        XCTAssertEqual(manager.appearance, .system)
    }

    func testPaletteForSystemSchemeFollowsSystem() {
        let manager = ThemeManager(defaults: defaults)
        manager.theme = .muted
        manager.appearance = .system

        XCTAssertEqual(manager.palette(for: .light), .mutedLight)
        XCTAssertEqual(manager.palette(for: .dark), .mutedDark)
    }

    func testPaletteForLightOverrideIgnoresSystem() {
        let manager = ThemeManager(defaults: defaults)
        manager.theme = .muted
        manager.appearance = .light

        XCTAssertEqual(manager.palette(for: .light), .mutedLight)
        XCTAssertEqual(manager.palette(for: .dark), .mutedLight)
    }

    func testPaletteForDarkOverrideIgnoresSystem() {
        let manager = ThemeManager(defaults: defaults)
        manager.theme = .vivid
        manager.appearance = .dark

        XCTAssertEqual(manager.palette(for: .light), .vividDark)
        XCTAssertEqual(manager.palette(for: .dark), .vividDark)
    }
}
