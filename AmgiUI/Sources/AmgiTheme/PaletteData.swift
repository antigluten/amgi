public import SwiftUI
import Foundation

/// JSON-Codable theme shape. Bundled themes ship as `.json` resources;
/// user-created themes (future) write the same shape into
/// `applicationSupport/Themes/`. Resolve to a runtime `Palette` for a
/// given `ColorScheme` via `resolve(scheme:)`.
public struct PaletteData: Codable, Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let light: PaletteScheme
    public let dark: PaletteScheme

    public init(id: String, displayName: String, light: PaletteScheme, dark: PaletteScheme) {
        self.id = id
        self.displayName = displayName
        self.light = light
        self.dark = dark
    }

    public func resolve(scheme: ColorScheme) -> Palette {
        let s = (scheme == .dark) ? dark : light
        return s.toPalette()
    }
}

/// One half of a theme (light or dark). Every slot must be present
/// — decoding fails otherwise.
public struct PaletteScheme: Codable, Sendable, Equatable {
    public let backgroundHex: String
    public let surfaceHex: String
    public let surfaceElevatedHex: String
    public let borderHex: String
    public let textPrimaryHex: String
    public let textSecondaryHex: String
    public let textTertiaryHex: String
    public let accentHex: String
    public let linkHex: String
    public let positiveHex: String
    public let warningHex: String
    public let dangerHex: String
    public let infoHex: String
    public let customStudyBadgeHex: String
    public let accentSoftHex: String
    public let separatorHex: String
    public let cardStateNewHex: String
    public let cardStateLearningHex: String
    public let cardStateReviewHex: String
    public let cardStateMatureHex: String
    public let cardStateSuspendedHex: String
    public let cardStateRelearnHex: String
    public let shadows: ShadowSet

    private enum CodingKeys: String, CodingKey {
        case backgroundHex = "background"
        case surfaceHex = "surface"
        case surfaceElevatedHex = "surfaceElevated"
        case borderHex = "border"
        case textPrimaryHex = "textPrimary"
        case textSecondaryHex = "textSecondary"
        case textTertiaryHex = "textTertiary"
        case accentHex = "accent"
        case linkHex = "link"
        case positiveHex = "positive"
        case warningHex = "warning"
        case dangerHex = "danger"
        case infoHex = "info"
        case customStudyBadgeHex = "customStudyBadge"
        case accentSoftHex = "accentSoft"
        case separatorHex = "separator"
        case cardStateNewHex = "cardStateNew"
        case cardStateLearningHex = "cardStateLearning"
        case cardStateReviewHex = "cardStateReview"
        case cardStateMatureHex = "cardStateMature"
        case cardStateSuspendedHex = "cardStateSuspended"
        case cardStateRelearnHex = "cardStateRelearn"
        case shadows
    }

    public init(
        backgroundHex: String,
        surfaceHex: String,
        surfaceElevatedHex: String,
        borderHex: String,
        textPrimaryHex: String,
        textSecondaryHex: String,
        textTertiaryHex: String,
        accentHex: String,
        linkHex: String,
        positiveHex: String,
        warningHex: String,
        dangerHex: String,
        infoHex: String,
        customStudyBadgeHex: String,
        accentSoftHex: String,
        separatorHex: String,
        cardStateNewHex: String,
        cardStateLearningHex: String,
        cardStateReviewHex: String,
        cardStateMatureHex: String,
        cardStateSuspendedHex: String,
        cardStateRelearnHex: String,
        shadows: ShadowSet
    ) {
        self.backgroundHex = backgroundHex
        self.surfaceHex = surfaceHex
        self.surfaceElevatedHex = surfaceElevatedHex
        self.borderHex = borderHex
        self.textPrimaryHex = textPrimaryHex
        self.textSecondaryHex = textSecondaryHex
        self.textTertiaryHex = textTertiaryHex
        self.accentHex = accentHex
        self.linkHex = linkHex
        self.positiveHex = positiveHex
        self.warningHex = warningHex
        self.dangerHex = dangerHex
        self.infoHex = infoHex
        self.customStudyBadgeHex = customStudyBadgeHex
        self.accentSoftHex = accentSoftHex
        self.separatorHex = separatorHex
        self.cardStateNewHex = cardStateNewHex
        self.cardStateLearningHex = cardStateLearningHex
        self.cardStateReviewHex = cardStateReviewHex
        self.cardStateMatureHex = cardStateMatureHex
        self.cardStateSuspendedHex = cardStateSuspendedHex
        self.cardStateRelearnHex = cardStateRelearnHex
        self.shadows = shadows
    }

    func toPalette() -> Palette {
        Palette(
            background: .fromHex(backgroundHex),
            surface: .fromHex(surfaceHex),
            surfaceElevated: .fromHex(surfaceElevatedHex),
            border: .fromHex(borderHex),
            textPrimary: .fromHex(textPrimaryHex),
            textSecondary: .fromHex(textSecondaryHex),
            textTertiary: .fromHex(textTertiaryHex),
            accent: .fromHex(accentHex),
            link: .fromHex(linkHex),
            positive: .fromHex(positiveHex),
            warning: .fromHex(warningHex),
            danger: .fromHex(dangerHex),
            info: .fromHex(infoHex),
            customStudyBadge: .fromHex(customStudyBadgeHex),
            accentSoft: .fromHex(accentSoftHex),
            separator: .fromHex(separatorHex),
            cardStateNew: .fromHex(cardStateNewHex),
            cardStateLearning: .fromHex(cardStateLearningHex),
            cardStateReview: .fromHex(cardStateReviewHex),
            cardStateMature: .fromHex(cardStateMatureHex),
            cardStateSuspended: .fromHex(cardStateSuspendedHex),
            cardStateRelearn: .fromHex(cardStateRelearnHex),
            shadows: shadows
        )
    }
}

// Hex parser accepts "#RRGGBB" or "#RRGGBBAA" (capital or lower).
// "#RGB" short form is not supported — themes always emit full hex.
extension Color {
    static func fromHex(_ hex: String) -> Color {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard let value = UInt64(trimmed, radix: 16) else { return .clear }
        let r, g, b, a: Double
        switch trimmed.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            return .clear
        }
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}
