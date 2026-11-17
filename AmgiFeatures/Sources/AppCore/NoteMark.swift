//
//  NoteMark.swift
//  AppCore
//

public import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Anki marks a note by giving it the `marked` tag.
public enum NoteMark {
    public static let tag = "marked"

    /// Whether a note's space-separated `tags` include `marked`, in any case.
    public static func isMarked(tags: String) -> Bool {
        tags.split(separator: " ").contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    /// The tint Anki gives marked notes' rows in its browser: its
    /// `state.marked` colour (`ts/lib/sass/_vars.scss`), indigo in light
    /// mode and purple in dark, laid over the row as a wash.
    public static var rowBackground: Color {
        adaptive(light: 0x6366F1, dark: 0xA855F7).opacity(0.16)
    }

    private static func rgb(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        #if os(iOS)
        let light = UIColor(rgb(light)), dark = UIColor(rgb(dark))
        return Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
        #elseif os(macOS)
        let light = NSColor(rgb(light)), dark = NSColor(rgb(dark))
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
        #else
        return rgb(dark)
        #endif
    }
}
