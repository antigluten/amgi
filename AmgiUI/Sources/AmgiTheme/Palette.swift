public import SwiftUI

public struct Palette: Sendable, Equatable {
    public let background: Color
    public let surface: Color
    public let surfaceElevated: Color
    public let border: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color
    public let accent: Color
    public let link: Color
    public let positive: Color
    public let warning: Color
    public let danger: Color
    public let info: Color
    public let customStudyBadge: Color
    public let accentSoft: Color
    public let separator: Color
    public let cardStateNew: Color
    public let cardStateLearning: Color
    public let cardStateReview: Color
    public let cardStateMature: Color
    public let cardStateSuspended: Color
    public let cardStateRelearn: Color
    public let shadows: ShadowSet

    public init(
        background: Color,
        surface: Color,
        surfaceElevated: Color,
        border: Color,
        textPrimary: Color,
        textSecondary: Color,
        textTertiary: Color,
        accent: Color,
        link: Color,
        positive: Color,
        warning: Color,
        danger: Color,
        info: Color,
        customStudyBadge: Color,
        accentSoft: Color,
        separator: Color,
        cardStateNew: Color,
        cardStateLearning: Color,
        cardStateReview: Color,
        cardStateMature: Color,
        cardStateSuspended: Color,
        cardStateRelearn: Color,
        shadows: ShadowSet
    ) {
        self.background = background
        self.surface = surface
        self.surfaceElevated = surfaceElevated
        self.border = border
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textTertiary = textTertiary
        self.accent = accent
        self.link = link
        self.positive = positive
        self.warning = warning
        self.danger = danger
        self.info = info
        self.customStudyBadge = customStudyBadge
        self.accentSoft = accentSoft
        self.separator = separator
        self.cardStateNew = cardStateNew
        self.cardStateLearning = cardStateLearning
        self.cardStateReview = cardStateReview
        self.cardStateMature = cardStateMature
        self.cardStateSuspended = cardStateSuspended
        self.cardStateRelearn = cardStateRelearn
        self.shadows = shadows
    }

    public static func resolve(theme: ThemeID, scheme: ColorScheme) -> Palette {
        if theme == .vivid {
            return scheme == .dark ? .vividDark : .vividLight
        } else if theme == .muted {
            return scheme == .dark ? .mutedDark : .mutedLight
        } else if theme == .sepia {
            return scheme == .dark ? .sepiaDark : .sepiaLight
        } else {
            return scheme == .dark ? .vividDark : .vividLight
        }
    }
}

// MARK: - Hex helpers (file-private)

private extension Color {
    static func hex(_ value: UInt32) -> Color {
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Vivid

public extension Palette {
    static let vividLight = Palette(
        background: .hex(0xF5F5F7),
        surface: .white,
        surfaceElevated: .white,
        border: .hex(0xE5E5EA),
        textPrimary: .hex(0x1D1D1F),
        textSecondary: Color.hex(0x1D1D1F).opacity(0.8),
        textTertiary: Color.hex(0x1D1D1F).opacity(0.48),
        accent: .hex(0x0071E3),
        link: .hex(0x0066CC),
        positive: .hex(0x34C759),
        warning: .hex(0xFF9500),
        danger: .hex(0xFF3B30),
        info: .hex(0x32ADE6),
        customStudyBadge: .hex(0xFF9300),
        accentSoft: Color.hex(0x0071E3).opacity(0.15),
        separator: Color.hex(0x1D1D1F).opacity(0.12),
        cardStateNew: .hex(0x0A84FF),
        cardStateLearning: .hex(0xFF9500),
        cardStateReview: .hex(0x30D158),
        cardStateMature: .hex(0xBF5AF2),
        cardStateSuspended: .hex(0x8E8E93),
        cardStateRelearn: .hex(0xFF3B30),
        shadows: ShadowSet(
            sm: ShadowSpec(radius: 2, dx: 0, dy: 1, opacity: 0.04),
            md: ShadowSpec(radius: 16, dx: 0, dy: 4, opacity: 0.06)
        )
    )

    static let vividDark = Palette(
        background: .black,
        surface: .hex(0x1C1C1E),
        surfaceElevated: .hex(0x2A2A2D),
        border: Color.white.opacity(0.12),
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.8),
        textTertiary: Color.white.opacity(0.48),
        accent: .hex(0x2997FF),
        link: .hex(0x2997FF),
        positive: .hex(0x30D158),
        warning: .hex(0xFF9F0A),
        danger: .hex(0xFF453A),
        info: .hex(0x64D2FF),
        customStudyBadge: .hex(0xFF9F0A),
        accentSoft: Color.hex(0x2997FF).opacity(0.22),
        separator: Color.white.opacity(0.10),
        cardStateNew: .hex(0x2997FF),
        cardStateLearning: .hex(0xFF9F0A),
        cardStateReview: .hex(0x30D158),
        cardStateMature: .hex(0xBF5AF2),
        cardStateSuspended: .hex(0x8E8E93),
        cardStateRelearn: .hex(0xFF453A),
        shadows: ShadowSet(
            sm: ShadowSpec(radius: 2, dx: 0, dy: 1, opacity: 0.18),
            md: ShadowSpec(radius: 20, dx: 0, dy: 6, opacity: 0.28)
        )
    )
}

// MARK: - Muted

public extension Palette {
    static let mutedLight = Palette(
        background: .hex(0xF2F0EC),
        surface: .hex(0xFAFAF7),
        surfaceElevated: .white,
        border: .hex(0xE0DCD3),
        textPrimary: .hex(0x2A2825),
        textSecondary: Color.hex(0x2A2825).opacity(0.7),
        textTertiary: Color.hex(0x2A2825).opacity(0.45),
        accent: .hex(0x4A6FA5),
        link: .hex(0x4A6FA5),
        positive: .hex(0x6B9472),
        warning: .hex(0xC99A55),
        danger: .hex(0xB5615C),
        info: .hex(0x6B92AB),
        customStudyBadge: .hex(0xC99A55),
        accentSoft: Color.hex(0x4A6FA5).opacity(0.14),
        separator: Color.hex(0x2A2825).opacity(0.10),
        cardStateNew: .hex(0x4A6FA5),
        cardStateLearning: .hex(0xC99A55),
        cardStateReview: .hex(0x6B9472),
        cardStateMature: .hex(0x8E6CA5),
        cardStateSuspended: .hex(0x968F85),
        cardStateRelearn: .hex(0xB5615C),
        shadows: ShadowSet(
            sm: ShadowSpec(radius: 2, dx: 0, dy: 1, opacity: 0.04),
            md: ShadowSpec(radius: 16, dx: 0, dy: 4, opacity: 0.07)
        )
    )

    static let mutedDark = Palette(
        background: .hex(0x1A1916),
        surface: .hex(0x232120),
        surfaceElevated: .hex(0x2C2A28),
        border: Color.white.opacity(0.10),
        textPrimary: .hex(0xE8E4DD),
        textSecondary: Color.hex(0xE8E4DD).opacity(0.7),
        textTertiary: Color.hex(0xE8E4DD).opacity(0.45),
        accent: .hex(0x8FAACC),
        link: .hex(0x8FAACC),
        positive: .hex(0x8FB597),
        warning: .hex(0xD9B27D),
        danger: .hex(0xD08F8B),
        info: .hex(0x95B7C9),
        customStudyBadge: .hex(0xD9B27D),
        accentSoft: Color.hex(0x8FAACC).opacity(0.20),
        separator: Color.white.opacity(0.08),
        cardStateNew: .hex(0x8FAACC),
        cardStateLearning: .hex(0xD9B27D),
        cardStateReview: .hex(0x8FB597),
        cardStateMature: .hex(0xB39FCC),
        cardStateSuspended: .hex(0xA8A19A),
        cardStateRelearn: .hex(0xD08F8B),
        shadows: ShadowSet(
            sm: ShadowSpec(radius: 2, dx: 0, dy: 1, opacity: 0.16),
            md: ShadowSpec(radius: 20, dx: 0, dy: 6, opacity: 0.24)
        )
    )
}

// MARK: - Sepia

public extension Palette {
    static let sepiaLight = Palette(
        background: .hex(0xF4ECD8),
        surface: .hex(0xFAF3E0),
        surfaceElevated: .hex(0xFFFAEC),
        border: .hex(0xE3D8BC),
        textPrimary: .hex(0x4A3F2A),
        textSecondary: Color.hex(0x4A3F2A).opacity(0.7),
        textTertiary: Color.hex(0x4A3F2A).opacity(0.45),
        accent: .hex(0x7A5C40),
        link: .hex(0x6B4F38),
        positive: .hex(0x6B9472),
        warning: .hex(0xC99A55),
        danger: .hex(0xB5615C),
        info: .hex(0x6B92AB),
        customStudyBadge: .hex(0xC99A55),
        accentSoft: Color.hex(0x7A5C40).opacity(0.16),
        separator: Color.hex(0x4A3F2A).opacity(0.14),
        cardStateNew: .hex(0x7A5C40),
        cardStateLearning: .hex(0xC99A55),
        cardStateReview: .hex(0x6B9472),
        cardStateMature: .hex(0x8E6CA5),
        cardStateSuspended: .hex(0x968F85),
        cardStateRelearn: .hex(0xB5615C),
        shadows: ShadowSet(
            sm: ShadowSpec(radius: 2, dx: 0, dy: 1, opacity: 0.05),
            md: ShadowSpec(radius: 16, dx: 0, dy: 4, opacity: 0.08)
        )
    )

    // Sepia tones don't read on a black background; intentionally
    // identical to Vivid Dark.
    static let sepiaDark = Palette.vividDark
}
