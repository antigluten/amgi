// AmgiUI/Tests/AmgiThemeTests/ThemeRegistryTests.swift
import XCTest
import SwiftUI
@testable import AmgiTheme

final class ThemeRegistryTests: XCTestCase {
    func testBootLoadsBundledThemes() {
        let registry = ThemeRegistry.shared
        let ids = registry.allThemes().map(\.id).sorted()
        XCTAssertTrue(ids.contains("vivid"))
        XCTAssertTrue(ids.contains("muted"))
        XCTAssertTrue(ids.contains("sepia"))
    }

    func testPaletteForKnownThemeLight() {
        let palette = ThemeRegistry.shared.palette(id: .vivid, scheme: .light)
        XCTAssertNotEqual(palette.accent, palette.background)
    }

    func testPaletteFallsBackToMinimalWhenIDUnknown() {
        let unknown = ThemeID(rawValue: "no-such-theme")
        let palette = ThemeRegistry.shared.palette(id: unknown, scheme: .light)
        XCTAssertEqual(palette.accent, ThemeRegistry.shared.palette(id: .minimal, scheme: .light).accent)
    }

    func testSepiaDarkSchemeReadsFromJSON() {
        // Sepia.json's dark section duplicates Vivid Dark's values. The
        // registry doesn't fall back at runtime — it reads what JSON says.
        let sepiaDark = ThemeRegistry.shared.palette(id: .sepia, scheme: .dark)
        let vividDark = ThemeRegistry.shared.palette(id: .vivid, scheme: .dark)
        XCTAssertEqual(sepiaDark.background, vividDark.background)
    }
}
