import Foundation
import SwiftUI

/// Typography settings persisted across reader sessions and surfaced
/// through `ReaderTypographySettingsView`. Defaults reflect a warm,
/// Apple Books-like reading style: 17pt System font, 1.55 line-height,
/// default margin (24px), Default theme, justified text.
///
/// `@Shared(.appStorage(...))` is used at the view layer with these
/// keys; this enum is the single source for key names + value enums so
/// the sheet and the chapter VC agree on the schema.
enum ReaderTypographyPreferences {
    enum Keys {
        static let fontFamily = "reader_typo_font_family"
        static let fontSize = "reader_typo_font_size"
        static let lineHeight = "reader_typo_line_height"
        static let pageMargin = "reader_typo_page_margin"
        static let theme = "reader_typo_theme"
        static let justify = "reader_typo_justify"
    }

    enum FontFamily: String, CaseIterable, Identifiable {
        case system, serif, sansSerif, mono
        var id: String { rawValue }

        /// CSS font-family stack pushed into `--reader-font-family`.
        var cssStack: String {
            switch self {
            case .system:    return "-apple-system, BlinkMacSystemFont, \"Helvetica Neue\", sans-serif"
            case .serif:     return "\"New York\", Georgia, \"Times New Roman\", serif"
            case .sansSerif: return "\"Helvetica Neue\", \"Avenir Next\", sans-serif"
            case .mono:      return "\"SF Mono\", Menlo, Consolas, monospace"
            }
        }

        var label: String {
            switch self {
            case .system: return "System"
            case .serif: return "Serif"
            case .sansSerif: return "Sans"
            case .mono: return "Mono"
            }
        }
    }

    enum PageMargin: String, CaseIterable, Identifiable {
        case compact, defaultMargin = "default", loose
        var id: String { rawValue }

        var pixels: Int {
            switch self {
            case .compact: return 12
            case .defaultMargin: return 24
            case .loose: return 40
            }
        }

        var label: String {
            switch self {
            case .compact: return "Compact"
            case .defaultMargin: return "Default"
            case .loose: return "Loose"
            }
        }
    }

    enum Theme: String, CaseIterable, Identifiable {
        case `default`, sepia, dark
        var id: String { rawValue }

        var label: String {
            switch self {
            case .default: return "Default"
            case .sepia: return "Sepia"
            case .dark: return "Dark"
            }
        }

        /// Hex strings consumed by the WebView CSS custom properties.
        var backgroundHex: String {
            switch self {
            case .default: return "#FAF7F1"
            case .sepia:   return "#F4ECD8"
            case .dark:    return "#1B1B1F"
            }
        }

        var foregroundHex: String {
            switch self {
            case .default: return "#1A1A1A"
            case .sepia:   return "#5B4636"
            case .dark:    return "#E8E6E3"
            }
        }

        var tokenUnderlineHex: String {
            switch self {
            case .default: return "rgba(80, 80, 80, 0.55)"
            case .sepia:   return "rgba(123, 84, 60, 0.55)"
            case .dark:    return "rgba(200, 200, 210, 0.55)"
            }
        }

        /// SwiftUI background for the chrome / WKWebView so there is no
        /// flash of system colour while the chapter loads.
        var backgroundColor: Color {
            Color(hex: backgroundHex) ?? .white
        }
    }
}

extension Color {
    /// Initialise from a "#RRGGBB" / "#AARRGGBB" hex literal. Returns
    /// nil for malformed input.
    init?(hex: String) {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard let value = UInt64(trimmed, radix: 16) else { return nil }
        switch trimmed.count {
        case 6:
            let r = Double((value & 0xFF0000) >> 16) / 255.0
            let g = Double((value & 0x00FF00) >> 8) / 255.0
            let b = Double(value & 0x0000FF) / 255.0
            self = Color(red: r, green: g, blue: b)
        case 8:
            let a = Double((value & 0xFF000000) >> 24) / 255.0
            let r = Double((value & 0x00FF0000) >> 16) / 255.0
            let g = Double((value & 0x0000FF00) >> 8) / 255.0
            let b = Double(value & 0x000000FF) / 255.0
            self = Color(red: r, green: g, blue: b, opacity: a)
        default:
            return nil
        }
    }
}
