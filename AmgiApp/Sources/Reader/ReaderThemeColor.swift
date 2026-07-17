import SwiftUI
import UIKit

/// Hex <-> SwiftUI.Color bridge for the reader's custom-theme editor.
/// Stored as `#RRGGBB` strings in `@Shared(.appStorage)` so the colours
/// round-trip through plist and slot directly into the chapter reader's
/// CSS without further conversion.
enum ReaderThemeColor {
    static func color(fromHex hex: String, fallback: Color) -> Color {
        guard let resolved = parseHex(hex) else { return fallback }
        return Color(red: resolved.r, green: resolved.g, blue: resolved.b)
    }

    static func hex(from color: Color) -> String {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return "#000000" }
        return String(format: "#%02X%02X%02X",
                      Int((r * 255).rounded()),
                      Int((g * 255).rounded()),
                      Int((b * 255).rounded()))
    }

    /// CSS-safe hex string. Empty input falls through to `defaultHex`,
    /// so callers can blanket-bind to a possibly-empty preference key.
    static func cssHex(_ hex: String, default defaultHex: String) -> String {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        return parseHex(trimmed) == nil ? defaultHex : trimmed
    }

    private static func parseHex(_ raw: String) -> (r: Double, g: Double, b: Double)? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }
}
