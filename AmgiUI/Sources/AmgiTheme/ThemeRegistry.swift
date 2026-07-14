// AmgiUI/Sources/AmgiTheme/ThemeRegistry.swift
public import SwiftUI
import Foundation

/// Loads bundled theme JSONs at boot and resolves `(ThemeID, ColorScheme)`
/// to a runtime `Palette`. Built-in themes are bundled resources; future
/// user-created themes will be scanned from `applicationSupport/Themes/`
/// and merged into the same registry without touching call sites.
public final class ThemeRegistry: @unchecked Sendable {
    public static let shared = ThemeRegistry()

    private let themesByID: [String: PaletteData]
    private let fallback: PaletteData

    /// Defaults to scanning `Bundle.module/themes/*.json`. Pass an
    /// override array for tests that want explicit fixtures.
    public init(bundleThemes: [PaletteData]? = nil) {
        let loaded = bundleThemes ?? Self.loadFromBundle()
        var byID: [String: PaletteData] = [:]
        for data in loaded {
            byID[data.id] = data
        }
        self.themesByID = byID
        // The fallback is whichever-one-of-minimal-or-first exists; minimal is
        // always bundled, so this is safe for the shipped app.
        self.fallback = byID["minimal"] ?? loaded.first ?? Self.emergencyFallback()
    }

    public func allThemes() -> [PaletteData] {
        themesByID.values.sorted { $0.id < $1.id }
    }

    public func palette(id: ThemeID, scheme: ColorScheme) -> Palette {
        let data = themesByID[id.rawValue] ?? fallback
        return data.resolve(scheme: scheme)
    }

    // MARK: - Bundle loading

    private static func loadFromBundle() -> [PaletteData] {
        // SPM .process("Resources") flattens sub-directories into the bundle
        // root, so the JSON files are at the top level with no subdirectory.
        let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: nil)
            ?? Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "themes")
            ?? []
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(PaletteData.self, from: data)
        }
    }

    /// Used only when the bundle has no themes — should never happen in
    /// release builds because the JSON resources are linked in.
    private static func emergencyFallback() -> PaletteData {
        let zero = ShadowSpec(radius: 0, dx: 0, dy: 0, opacity: 0)
        let scheme = PaletteScheme(
            backgroundHex: "#FFFFFF",
            surfaceHex: "#FFFFFF",
            surfaceElevatedHex: "#FFFFFF",
            borderHex: "#E5E5EA",
            textPrimaryHex: "#000000",
            textSecondaryHex: "#000000",
            textTertiaryHex: "#000000",
            accentHex: "#0071E3",
            linkHex: "#0071E3",
            positiveHex: "#34C759",
            warningHex: "#FF9500",
            dangerHex: "#FF3B30",
            infoHex: "#32ADE6",
            customStudyBadgeHex: "#FF9300",
            accentSoftHex: "#0071E326",
            separatorHex: "#0000001F",
            cardStateNewHex: "#0A84FF",
            cardStateLearningHex: "#FF9500",
            cardStateReviewHex: "#30D158",
            cardStateMatureHex: "#BF5AF2",
            cardStateSuspendedHex: "#8E8E93",
            cardStateRelearnHex: "#FF3B30",
            shadows: ShadowSet(sm: zero, md: zero)
        )
        return PaletteData(id: "vivid", displayName: "Vivid", light: scheme, dark: scheme)
    }
}
