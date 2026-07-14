import Foundation

/// String-keyed identifier for a theme. Built-in themes ship as
/// `public static let` constants; user-created themes (future) register
/// new IDs through `ThemeRegistry` without touching this file.
public struct ThemeID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let vivid = ThemeID(rawValue: "vivid")
    public static let muted = ThemeID(rawValue: "muted")
    public static let sepia = ThemeID(rawValue: "sepia")
    public static let minimal = ThemeID(rawValue: "minimal")
}

public enum Appearance: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}
