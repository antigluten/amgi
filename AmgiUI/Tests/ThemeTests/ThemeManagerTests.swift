//
//  ThemeManagerTests.swift
//  ThemeTests
//
//  Created by Vladimir Gusev on 28.04.2026.
//

import Foundation
import Testing
import SwiftUI
@testable import Theme

// `final class`, not `struct`: the suite needs a `deinit` to tear the
// throwaway UserDefaults suite back off disk. `@MainActor` because
// `ThemeManager` is.
@MainActor
@Suite("ThemeManager")
final class ThemeManagerTests {
    private let suiteName: String
    private let defaults: UserDefaults

    init() {
        let name = "test-suite-\(UUID().uuidString)"
        suiteName = name
        defaults = UserDefaults(suiteName: name)!
    }

    deinit {
        // Fresh instance: `defaults` is non-Sendable and `deinit` is nonisolated.
        // `removePersistentDomain(forName:)` acts on the named domain, not the receiver.
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    @Test func defaultValuesOnEmptyStore() {
        let manager = ThemeManager(defaults: defaults)
        #expect(manager.themeID == .minimal)
        #expect(manager.appearance == .system)
    }

    @Test func settingThemeIDPersists() {
        let m1 = ThemeManager(defaults: defaults)
        m1.themeID = .sepia
        m1.appearance = .dark

        let m2 = ThemeManager(defaults: defaults)
        #expect(m2.themeID == .sepia)
        #expect(m2.appearance == .dark)
    }

    @Test func paletteResolvesThroughRegistry() {
        let manager = ThemeManager(defaults: defaults)
        manager.themeID = .sepia
        let palette = manager.palette(for: .light)
        let expected = ThemeRegistry.shared.palette(id: .sepia, scheme: .light)
        #expect(palette.background == expected.background)
        #expect(palette.accent == expected.accent)
    }

    @Test func appearanceLightOverridesSystemScheme() {
        let manager = ThemeManager(defaults: defaults)
        manager.appearance = .light
        // Even with systemScheme=.dark, .light appearance should pick the light palette
        let palette = manager.palette(for: .dark)
        let expected = ThemeRegistry.shared.palette(id: .minimal, scheme: .light)
        #expect(palette.background == expected.background)
    }

    @Test func readsLegacyThemeKeyOnFirstUpgrade() {
        // Pre-populate the suite with only the legacy key
        defaults.set("muted", forKey: "theme.selection")
        let manager = ThemeManager(defaults: defaults)
        #expect(manager.themeID == .muted)
    }
}
