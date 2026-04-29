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
        customStudyBadge: Color
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
    }

    public static func resolve(theme: Theme, scheme: ColorScheme) -> Palette {
        switch (theme, scheme) {
        case (.vivid, .light): return .vividLight
        case (.vivid, .dark): return .vividDark
        case (.muted, .light): return .mutedLight
        case (.muted, .dark): return .mutedDark
        @unknown default: return .vividLight
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
        customStudyBadge: .hex(0xFF9300)
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
        customStudyBadge: .hex(0xFF9F0A)
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
        customStudyBadge: .hex(0xC99A55)
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
        customStudyBadge: .hex(0xD9B27D)
    )
}
