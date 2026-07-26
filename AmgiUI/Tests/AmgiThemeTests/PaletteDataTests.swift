import XCTest
import SwiftUI
@testable import AmgiTheme

final class PaletteDataTests: XCTestCase {
    private func sampleJSON() -> Data {
        // Minimal but valid PaletteData
        """
        {
          "id": "test",
          "displayName": "Test",
          "light": {
            "background": "#FFFFFF",
            "surface": "#F5F5F5",
            "surfaceElevated": "#FFFFFF",
            "border": "#E5E5EA",
            "textPrimary": "#1D1D1F",
            "textSecondary": "#1D1D1FCC",
            "textTertiary": "#1D1D1F7A",
            "accent": "#0071E3",
            "link": "#0066CC",
            "positive": "#34C759",
            "warning": "#FF9500",
            "danger": "#FF3B30",
            "info": "#32ADE6",
            "customStudyBadge": "#FF9300",
            "accentSoft": "#0071E326",
            "separator": "#1D1D1F1F",
            "cardStateNew": "#0A84FF",
            "cardStateLearning": "#FF9500",
            "cardStateReview": "#30D158",
            "cardStateMature": "#BF5AF2",
            "cardStateSuspended": "#8E8E93",
            "cardStateRelearn": "#FF3B30",
            "shadows": {
              "sm": { "radius": 2, "dx": 0, "dy": 1, "opacity": 0.04 },
              "md": { "radius": 16, "dx": 0, "dy": 4, "opacity": 0.06 }
            }
          },
          "dark": {
            "background": "#000000",
            "surface": "#1C1C1E",
            "surfaceElevated": "#2A2A2D",
            "border": "#FFFFFF1F",
            "textPrimary": "#FFFFFF",
            "textSecondary": "#FFFFFFCC",
            "textTertiary": "#FFFFFF7A",
            "accent": "#2997FF",
            "link": "#2997FF",
            "positive": "#30D158",
            "warning": "#FF9F0A",
            "danger": "#FF453A",
            "info": "#64D2FF",
            "customStudyBadge": "#FF9F0A",
            "accentSoft": "#2997FF38",
            "separator": "#FFFFFF1A",
            "cardStateNew": "#2997FF",
            "cardStateLearning": "#FF9F0A",
            "cardStateReview": "#30D158",
            "cardStateMature": "#BF5AF2",
            "cardStateSuspended": "#8E8E93",
            "cardStateRelearn": "#FF453A",
            "shadows": {
              "sm": { "radius": 2, "dx": 0, "dy": 1, "opacity": 0.18 },
              "md": { "radius": 20, "dx": 0, "dy": 6, "opacity": 0.28 }
            }
          }
        }
        """.data(using: .utf8)!
    }

    func testDecode() throws {
        let data = try JSONDecoder().decode(PaletteData.self, from: sampleJSON())
        XCTAssertEqual(data.id, "test")
        XCTAssertEqual(data.displayName, "Test")
        XCTAssertEqual(data.light.accentHex, "#0071E3")
    }

    func testResolveLightProducesPalette() throws {
        let data = try JSONDecoder().decode(PaletteData.self, from: sampleJSON())
        let palette = data.resolve(scheme: .light)
        XCTAssertNotEqual(palette.cardStateNew, palette.cardStateLearning)
        XCTAssertEqual(palette.shadows.md.radius, 16)
    }

    func testResolveDarkUsesDarkScheme() throws {
        let data = try JSONDecoder().decode(PaletteData.self, from: sampleJSON())
        let palette = data.resolve(scheme: .dark)
        XCTAssertEqual(palette.shadows.md.radius, 20)
    }

    func testRejectsMissingSlot() {
        let bad = """
        { "id": "x", "displayName": "X", "light": {}, "dark": {} }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(PaletteData.self, from: bad))
    }
}
