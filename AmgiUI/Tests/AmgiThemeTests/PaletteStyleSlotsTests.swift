import Testing
import SwiftUI
@testable import AmgiTheme

@Suite("Palette style slots")
struct PaletteStyleSlotsTests {

    /// Every slot present, NO elevation/deckGlyph keys — the legacy shape.
    private func legacyJSON() -> Data {
        Data(schemeJSON(themeExtra: "").utf8)
    }

    private func minimalStyleJSON() -> Data {
        Data(schemeJSON(themeExtra: #""elevation": "ring", "deckGlyph": "monogram","#).utf8)
    }

    private func schemeJSON(themeExtra: String) -> String {
        let scheme = """
        {
          "background": "#FFFFFF", "surface": "#F5F5F5", "surfaceElevated": "#FFFFFF",
          "border": "#E5E5EA", "textPrimary": "#1D1D1F", "textSecondary": "#1D1D1FCC",
          "textTertiary": "#1D1D1F7A", "accent": "#0071E3", "link": "#0066CC",
          "positive": "#34C759", "warning": "#FF9500", "danger": "#FF3B30",
          "info": "#32ADE6", "customStudyBadge": "#FF9300", "accentSoft": "#0071E326",
          "separator": "#1D1D1F1F", "cardStateNew": "#0A84FF",
          "cardStateLearning": "#FF9500", "cardStateReview": "#30D158",
          "cardStateMature": "#BF5AF2", "cardStateSuspended": "#8E8E93",
          "cardStateRelearn": "#FF3B30",
          "shadows": { "sm": { "radius": 2, "dx": 0, "dy": 1, "opacity": 0.04 },
                       "md": { "radius": 16, "dx": 0, "dy": 4, "opacity": 0.06 } }
        }
        """
        return """
        { "id": "test", "displayName": "Test", \(themeExtra)
          "light": \(scheme), "dark": \(scheme) }
        """
    }

    @Test func legacyJSONDefaultsToShadowAndEmoji() throws {
        let data = try JSONDecoder().decode(PaletteData.self, from: legacyJSON())
        let palette = data.resolve(scheme: .light)
        #expect(palette.elevation == .shadow)
        #expect(palette.deckGlyph == .emoji)
    }

    @Test func ringAndMonogramDecode() throws {
        let data = try JSONDecoder().decode(PaletteData.self, from: minimalStyleJSON())
        #expect(data.elevation == .ring)
        #expect(data.deckGlyph == .monogram)
        let palette = data.resolve(scheme: .dark)
        #expect(palette.elevation == .ring)
        #expect(palette.deckGlyph == .monogram)
    }

    @Test func staticPalettesDefaultToShadowAndEmoji() {
        #expect(Palette.vividLight.elevation == .shadow)
        #expect(Palette.vividLight.deckGlyph == .emoji)
    }
}
