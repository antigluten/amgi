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
        XCTAssertEqual(manager.themeID, .vivid)
        XCTAssertEqual(manager.appearance, .system)
    }

    func testSettingThemeIDPersists() {
        let m1 = ThemeManager(defaults: defaults)
        m1.themeID = .sepia
        m1.appearance = .dark

        let m2 = ThemeManager(defaults: defaults)
        XCTAssertEqual(m2.themeID, .sepia)
        XCTAssertEqual(m2.appearance, .dark)
    }

    func testPaletteResolvesThroughRegistry() {
        let manager = ThemeManager(defaults: defaults)
        manager.themeID = .sepia
        let palette = manager.palette(for: .light)
        let expected = ThemeRegistry.shared.palette(id: .sepia, scheme: .light)
        XCTAssertEqual(palette.background, expected.background)
        XCTAssertEqual(palette.accent, expected.accent)
    }

    func testAppearanceLightOverridesSystemScheme() {
        let manager = ThemeManager(defaults: defaults)
        manager.appearance = .light
        // Even with systemScheme=.dark, .light appearance should pick the light palette
        let palette = manager.palette(for: .dark)
        let expected = ThemeRegistry.shared.palette(id: .vivid, scheme: .light)
        XCTAssertEqual(palette.background, expected.background)
    }

    func testReadsLegacyThemeKeyOnFirstUpgrade() {
        // Pre-populate the suite with only the legacy key
        defaults.set("muted", forKey: "theme.selection")
        let manager = ThemeManager(defaults: defaults)
        XCTAssertEqual(manager.themeID, .muted)
    }
}
