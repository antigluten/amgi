import Testing
import SwiftUI
@testable import AmgiTheme

@Suite("Minimal theme")
struct MinimalThemeTests {

    @Test func bundleShipsFourThemes() {
        let ids = ThemeRegistry.shared.allThemes().map(\.id).sorted()
        #expect(ids == ["minimal", "muted", "sepia", "vivid"])
    }

    @Test func minimalUsesRingAndMonogram() {
        let light = ThemeRegistry.shared.palette(id: .minimal, scheme: .light)
        #expect(light.elevation == .ring)
        #expect(light.deckGlyph == .monogram)
    }

    @Test func unknownIDFallsBackToMinimal() {
        let fallback = ThemeRegistry.shared.palette(id: ThemeID(rawValue: "nope"), scheme: .light)
        let minimal = ThemeRegistry.shared.palette(id: .minimal, scheme: .light)
        #expect(fallback == minimal)
    }

    @Test func managerDefaultsToMinimalWhenNothingStored() {
        let suite = UserDefaults(suiteName: "MinimalThemeTests-\(UUID().uuidString)")!
        let manager = ThemeManager(defaults: suite)
        #expect(manager.themeID == .minimal)
    }

    @Test func minimalShadowsAreZeroed() {
        let light = ThemeRegistry.shared.palette(id: .minimal, scheme: .light)
        #expect(light.shadows.sm.opacity == 0)
        #expect(light.shadows.md.opacity == 0)
    }
}
