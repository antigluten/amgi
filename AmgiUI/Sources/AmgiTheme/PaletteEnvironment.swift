public import SwiftUI

public extension EnvironmentValues {
    @Entry var palette: Palette = .vividLight
}

public extension View {
    /// Apply at the app's root view. Reads `ThemeManager` and writes the resolved
    /// `Palette` into the environment plus applies `.preferredColorScheme(...)`
    /// when the user has overridden the system appearance.
    func themedRoot(manager: ThemeManager = .shared) -> some View {
        modifier(ThemedRootModifier(manager: manager))
    }
}

private struct ThemedRootModifier: ViewModifier {
    @Bindable var manager: ThemeManager
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        content
            .environment(\.palette, manager.palette(for: systemScheme))
            .preferredColorScheme(preferredScheme)
    }

    private var preferredScheme: ColorScheme? {
        switch manager.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
