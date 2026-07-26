public import SwiftUI

/// User-selectable typeface preference. Resolved through `\.appFont`
/// environment, consumed by `AmgiFont` so every `.amgiFont(...)` call
/// site picks up the user's choice. Orthogonal to theme and appearance.
public enum AppFont: String, CaseIterable, Sendable, Codable {
    case system   // SF Pro (default)
    case serif    // New York (system serif)
}

private struct AppFontKey: EnvironmentKey {
    static let defaultValue: AppFont = .system
}

public extension EnvironmentValues {
    var appFont: AppFont {
        get { self[AppFontKey.self] }
        set { self[AppFontKey.self] = newValue }
    }
}
