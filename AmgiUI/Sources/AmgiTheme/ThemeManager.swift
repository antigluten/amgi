public import Foundation
public import SwiftUI

@Observable
public final class ThemeManager: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = ThemeManager()

    public var theme: Theme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    public var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .amgiAppGroup) {
        self.defaults = defaults
        let storedTheme = defaults.string(forKey: Keys.theme).flatMap(Theme.init(rawValue:))
        let storedAppearance = defaults.string(forKey: Keys.appearance).flatMap(Appearance.init(rawValue:))
        self.theme = storedTheme ?? .vivid
        self.appearance = storedAppearance ?? .system
    }

    public func palette(for systemScheme: ColorScheme) -> Palette {
        let resolved: ColorScheme
        switch appearance {
        case .system: resolved = systemScheme
        case .light: resolved = .light
        case .dark: resolved = .dark
        }
        return Palette.resolve(theme: theme, scheme: resolved)
    }

    private enum Keys {
        static let theme = "theme.selection"
        static let appearance = "theme.appearance"
    }
}
