//
//  PaletteContrastTests.swift
//  ThemeTests
//
//  Created by Vladimir Gusev on 18.09.2026.
//

import Foundation
import Testing
@testable import Theme

@Suite("Palette contrast")
struct PaletteContrastTests {

    private static let themes = ThemeRegistry().allThemes()

    private static var textTokens: [(name: String, hex: KeyPath<PaletteScheme, String>)] { [
        ("textPrimary", \.textPrimaryHex),
        ("textSecondary", \.textSecondaryHex),
        ("textTertiary", \.textTertiaryHex),
        ("accent", \.accentHex),
        ("link", \.linkHex),
        ("positive", \.positiveHex),
        ("warning", \.warningHex),
        ("danger", \.dangerHex),
        ("info", \.infoHex),
        ("customStudyBadge", \.customStudyBadgeHex),
        ("cardStateNew", \.cardStateNewHex),
        ("cardStateLearning", \.cardStateLearningHex),
        ("cardStateReview", \.cardStateReviewHex),
        ("cardStateMature", \.cardStateMatureHex),
        ("cardStateSuspended", \.cardStateSuspendedHex),
        ("cardStateRelearn", \.cardStateRelearnHex),
    ] }

    @Test("Text tokens clear WCAG AA on background and surface", arguments: Self.themes)
    func textTokensClearAA(theme: PaletteData) {
        for (label, scheme) in [("light", theme.light), ("dark", theme.dark)] {
            let grounds = [
                ("background", scheme.backgroundHex),
                ("surface", scheme.surfaceHex),
            ]
            for (token, path) in Self.textTokens {
                for (groundName, groundHex) in grounds {
                    let ratio = contrastRatio(scheme[keyPath: path], on: groundHex)
                    #expect(
                        ratio >= 4.5,
                        """
                        \(theme.id).\(label).\(token) = \(scheme[keyPath: path]) \
                        on \(groundName) \(groundHex) is \(String(format: "%.2f", ratio)):1, \
                        below WCAG AA 4.5:1
                        """
                    )
                }
            }
        }
    }

    @Test("Custom-study badge glyph clears WCAG AA on its own fill", arguments: Self.themes)
    func badgeGlyphClearsAA(theme: PaletteData) {
        for (label, scheme) in [("light", theme.light), ("dark", theme.dark)] {
            let ratio = contrastRatio(scheme.backgroundHex, on: scheme.customStudyBadgeHex)
            #expect(
                ratio >= 4.5,
                """
                \(theme.id).\(label): background glyph \(scheme.backgroundHex) on \
                customStudyBadge fill \(scheme.customStudyBadgeHex) is \
                \(String(format: "%.2f", ratio)):1, below WCAG AA 4.5:1
                """
            )
        }
    }

    @Test("No two themes share a colour scheme")
    func schemesAreDistinct() {
        // PaletteScheme is Equatable, not Hashable, so this is a pairwise
        // scan rather than a set — 8 schemes, the cost is irrelevant.
        let all = Self.themes.flatMap { theme in
            [("\(theme.id).light", theme.light), ("\(theme.id).dark", theme.dark)]
        }
        for i in all.indices {
            for j in all.indices where j > i {
                if all[i].1 == all[j].1 {
                    Issue.record("\(all[j].0) is identical to \(all[i].0)")
                }
            }
        }
    }

    @Test("No pure black grounds or pure white text", arguments: Self.themes)
    func avoidsPureExtremes(theme: PaletteData) {
        for (label, scheme) in [("light", theme.light), ("dark", theme.dark)] {
            #expect(
                scheme.backgroundHex.uppercased() != "#000000",
                "\(theme.id).\(label).background is pure black"
            )
            #expect(
                scheme.textPrimaryHex.uppercased() != "#FFFFFF",
                "\(theme.id).\(label).textPrimary is pure white"
            )
        }
    }

    // MARK: - WCAG 2.1 relative luminance

    private func contrastRatio(_ hex: String, on groundHex: String) -> Double {
        let ground = components(groundHex)
        let fg = composite(components(hex), over: ground)
        let (l1, l2) = (luminance(fg), luminance(ground))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    private func components(_ hex: String) -> (r: Double, g: Double, b: Double, a: Double) {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard let value = UInt64(trimmed, radix: 16) else { return (0, 0, 0, 1) }
        switch trimmed.count {
        case 6:
            return (
                Double((value >> 16) & 0xFF) / 255,
                Double((value >> 8) & 0xFF) / 255,
                Double(value & 0xFF) / 255,
                1
            )
        case 8:
            return (
                Double((value >> 24) & 0xFF) / 255,
                Double((value >> 16) & 0xFF) / 255,
                Double((value >> 8) & 0xFF) / 255,
                Double(value & 0xFF) / 255
            )
        default:
            return (0, 0, 0, 1)
        }
    }

    private func composite(
        _ fg: (r: Double, g: Double, b: Double, a: Double),
        over bg: (r: Double, g: Double, b: Double, a: Double)
    ) -> (r: Double, g: Double, b: Double, a: Double) {
        (
            fg.r * fg.a + bg.r * (1 - fg.a),
            fg.g * fg.a + bg.g * (1 - fg.a),
            fg.b * fg.a + bg.b * (1 - fg.a),
            1
        )
    }

    private func luminance(_ c: (r: Double, g: Double, b: Double, a: Double)) -> Double {
        func linear(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }
}
