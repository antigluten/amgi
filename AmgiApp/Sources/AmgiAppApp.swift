//
//  AmgiAppApp.swift
//  AmgiApp
//
//  Created by Vladimir Gusev on 27.03.2026.
//

import AppIntents
import SwiftUI
import RootFeature

/// The iOS app target holds only `@main` and the `AppShortcutsProvider`
/// (`Intents/AmgiShortcuts.swift`, which cannot live in a package target).
/// Dependency composition lives in `AmgiRoot.bootstrap()` and view composition
/// in `RootView`, both in the `RootFeature` package target — which is what lets
/// every other feature module drop from `public` to `package`.
@main
struct AnkiAppApp: App {
    init() {
        AmgiRoot.bootstrap()
        // Refreshes the deck list Siri offers for "Study <deck> in Amgi".
        AmgiShortcuts.updateAppShortcutParameters()
    }
    var body: some Scene { WindowGroup { RootView() } }
}
