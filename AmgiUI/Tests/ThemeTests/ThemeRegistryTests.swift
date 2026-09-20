//
//  ThemeRegistryTests.swift
//  ThemeTests
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import Testing
import SwiftUI
@testable import Theme

@Suite("ThemeRegistry")
struct ThemeRegistryTests {
    @Test(arguments: ["vivid", "muted", "sepia"])
    func bootLoadsBundledTheme(id: String) {
        #expect(ThemeRegistry.shared.allThemes().map(\.id).contains(id))
    }

    @Test func paletteForKnownThemeLight() {
        let palette = ThemeRegistry.shared.palette(id: .vivid, scheme: .light)
        #expect(palette.accent != palette.background)
    }

    @Test func paletteFallsBackToMinimalWhenIDUnknown() {
        let palette = ThemeRegistry.shared.palette(id: ThemeID(rawValue: "no-such-theme"), scheme: .light)
        #expect(palette.accent == ThemeRegistry.shared.palette(id: .minimal, scheme: .light).accent)
    }

    @Test func sepiaDarkSchemeReadsFromJSON() {
        let sepiaDark = ThemeRegistry.shared.palette(id: .sepia, scheme: .dark)
        let vividDark = ThemeRegistry.shared.palette(id: .vivid, scheme: .dark)
        #expect(sepiaDark.background == Color.fromHex("#14100B"))
        #expect(sepiaDark.background != vividDark.background)
    }
}
