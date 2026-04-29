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
    }

    func testMutedDiffersFromVivid() {
        XCTAssertNotEqual(Palette.vividLight.accent, Palette.mutedLight.accent)
        XCTAssertNotEqual(Palette.vividDark.background, Palette.mutedDark.background)
    }
}
