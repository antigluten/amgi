public import Foundation
public import SwiftUI

@Observable
public final class ThemeManager: @unchecked Sendable {
    public static let shared = ThemeManager()

    public var themeID: ThemeID {
        didSet { defaults.set(themeID.rawValue, forKey: Keys.themeID) }
    }

    public var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private let defaults: UserDefaults
    private let registry: ThemeRegistry

    public init(defaults: UserDefaults = .amgiAppGroup, registry: ThemeRegistry = .shared) {
        self.defaults = defaults
        self.registry = registry
        // First-upgrade backfill: read the legacy "theme.selection" key when
        // the new "theme.id" key isn't present yet. The didSet on themeID
        // will write the new key on the next change, so this only fires once.
        let storedRaw = defaults.string(forKey: Keys.themeID)
            ?? defaults.string(forKey: Keys.legacyTheme)
        let stored = storedRaw.map(ThemeID.init(rawValue:))
        let storedAppearance = defaults.string(forKey: Keys.appearance).flatMap(Appearance.init(rawValue:))
        // Unknown IDs are fine — registry.palette(id:scheme:) falls back to Minimal.
        self.themeID = stored ?? .minimal
        self.appearance = storedAppearance ?? .system
    }

    public func palette(for systemScheme: ColorScheme) -> Palette {
        let resolved: ColorScheme
        switch appearance {
        case .system: resolved = systemScheme
        case .light: resolved = .light
        case .dark: resolved = .dark
        }
        return registry.palette(id: themeID, scheme: resolved)
    }

    private enum Keys {
        static let themeID = "theme.id"
        static let legacyTheme = "theme.selection"
        static let appearance = "theme.appearance"
    }
}
