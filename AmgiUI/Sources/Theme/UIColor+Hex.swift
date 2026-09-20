//
//  UIColor+Hex.swift
//  Theme
//
//  Created by Vladimir Gusev on 20.08.2026.
//

#if canImport(UIKit)
public import UIKit

/// Hex ↔ `UIColor` conversion, shared by the reader and the image-occlusion
/// editor.
///
/// Both carried their own copy, and they disagreed on malformed input: one
/// stripped every non-alphanumeric character, the other trimmed only
/// whitespace and a leading `#`. Lives beside `Color.fromHex` in Theme
/// so there is one answer.
extension UIColor {
    /// Parses `RRGGBB` or `RRGGBBAA`, with or without a leading `#`.
    /// Returns nil for malformed input so callers can fall back rather than
    /// render a wrong colour.
    public convenience init?(amgiHex hex: String) {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6 || trimmed.count == 8,
              let value = UInt64(trimmed, radix: 16) else {
            return nil
        }

        let red, green, blue, alpha: CGFloat
        if trimmed.count == 8 {
            red = CGFloat((value & 0xFF00_0000) >> 24) / 255
            green = CGFloat((value & 0x00FF_0000) >> 16) / 255
            blue = CGFloat((value & 0x0000_FF00) >> 8) / 255
            alpha = CGFloat(value & 0x0000_00FF) / 255
        } else {
            red = CGFloat((value & 0xFF_0000) >> 16) / 255
            green = CGFloat((value & 0x00_FF00) >> 8) / 255
            blue = CGFloat(value & 0x00_00FF) / 255
            alpha = 1
        }
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// `RRGGBB` or `RRGGBBAA`, uppercase, no leading `#`.
    ///
    /// Converts to sRGB and clamps first: a Display P3 colour returns
    /// components outside 0...1, and `%02X` formats a negative `Int` as
    /// eight hex characters rather than two.
    public func amgiHexString(includeAlpha: Bool = false) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 1
        let converted = cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent,
            options: nil
        ).map(UIColor.init(cgColor:)) ?? self
        // getRed returns false for pattern colours; zeroed components with
        // opaque alpha give a defined black rather than garbage.
        if !converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            red = 0; green = 0; blue = 0; alpha = 1
        }
        func channel(_ value: CGFloat) -> Int {
            min(255, max(0, Int((value * 255).rounded())))
        }
        let rgb = String(format: "%02X%02X%02X", channel(red), channel(green), channel(blue))
        return includeAlpha ? rgb + String(format: "%02X", channel(alpha)) : rgb
    }
}
#endif
