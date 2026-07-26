import XCTest
import SwiftUI
@testable import AmgiTheme

final class PaletteTests: XCTestCase {
    func testResolveAllCombinations() {
        XCTAssertEqual(Palette.resolve(theme: .vivid, scheme: .light), .vividLight)
        XCTAssertEqual(Palette.resolve(theme: .vivid, scheme: .dark), .vividDark)
        XCTAssertEqual(Palette.resolve(theme: .muted, scheme: .light), .mutedLight)
        XCTAssertEqual(Palette.resolve(theme: .muted, scheme: .dark), .mutedDark)
    }

    func testVividLightHasAllSlotsPopulated() {
        let p = Palette.vividLight
        XCTAssertNotEqual(p.background, p.surface)
        XCTAssertNotEqual(p.textPrimary, p.textSecondary)
        XCTAssertNotEqual(p.accent, p.danger)
        XCTAssertNotEqual(p.cardStateNew, p.cardStateLearning)
        XCTAssertNotEqual(p.accent, p.accentSoft)
        XCTAssertGreaterThan(p.shadows.md.radius, p.shadows.sm.radius)
    }

    func testMutedDiffersFromVivid() {
        XCTAssertNotEqual(Palette.vividLight.accent, Palette.mutedLight.accent)
        XCTAssertNotEqual(Palette.vividDark.background, Palette.mutedDark.background)
    }

    func testSepiaLightExists() {
        let p = Palette.sepiaLight
        // Warm paper background, brown text — confirm it's neither Vivid nor Muted.
        XCTAssertNotEqual(p.background, Palette.vividLight.background)
        XCTAssertNotEqual(p.background, Palette.mutedLight.background)
    }

    func testSepiaDarkFallsBackToVividDarkValues() {
        // Sepia tones don't read on a black background; sepia dark
        // intentionally mirrors Vivid Dark's slot values.
        XCTAssertEqual(Palette.sepiaDark.background, Palette.vividDark.background)
        XCTAssertEqual(Palette.sepiaDark.accent, Palette.vividDark.accent)
    }
}
