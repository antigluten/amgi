//
//  PaletteTests.swift
//  ThemeTests
//
//  Created by Vladimir Gusev on 28.04.2026.
//

import Testing
import SwiftUI
@testable import Theme

@Suite("Built-in palettes")
struct PaletteTests {
    @Test func vividLightHasAllSlotsPopulated() {
        let p = Palette.vividLight
        #expect(p.background != p.surface)
        #expect(p.textPrimary != p.textSecondary)
        #expect(p.accent != p.danger)
        #expect(p.cardStateNew != p.cardStateLearning)
        #expect(p.accent != p.accentSoft)
        #expect(p.shadows.md.radius > p.shadows.sm.radius)
    }

    @Test func mutedDiffersFromVivid() {
        #expect(Palette.vividLight.accent != Palette.mutedLight.accent)
        #expect(Palette.vividDark.background != Palette.mutedDark.background)
    }

    @Test func sepiaLightExists() {
        let p = Palette.sepiaLight
        // Warm paper background, brown text — confirm it's neither Vivid nor Muted.
        #expect(p.background != Palette.vividLight.background)
        #expect(p.background != Palette.mutedLight.background)
    }

    @Test func sepiaDarkFallsBackToVividDarkValues() {
        // Sepia tones don't read on a black background; sepia dark
        // intentionally mirrors Vivid Dark's slot values.
        #expect(Palette.sepiaDark.background == Palette.vividDark.background)
        #expect(Palette.sepiaDark.accent == Palette.vividDark.accent)
    }
}
