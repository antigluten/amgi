//
//  Bootstrap.swift
//  RootFeature
//
//  Created by Vladimir Gusev on 29.08.2026.
//

import AppCore
import Reader
import AnkiBackend
import AnkiClients
import Dependencies
import Foundation
import SyncFeature

/// The app's dependency bootstrap. Called once from the host's `App.init`.
public enum AmgiRoot {
    /// Set when the collection could not be opened at launch. Read by
    /// `RootView` to route to `StartupErrorView`. Decided once during
    /// `bootstrap()` and never changed afterwards.
    @MainActor private(set) static var startupError: String?

    @MainActor
    public static func bootstrap() {
        AppSignpost.measure("Bootstrap") { bootstrapBody() }
    }

    @MainActor
    private static func bootstrapBody() {
        // Multi-profile bootstrap: migrate legacy single-collection layout
        // into the default profile, then open the selected profile's
        // collection.
        AccountStore.migrateLegacyCollectionIfNeeded()
        let activeProfile = AccountStore.shared.current

        // `try!` here turned any collection-open failure into a crash inside
        // init — on every launch, permanently, with no in-app recovery. A
        // corrupt collection.anki2, a schema written by a newer Anki, or a
        // full disk left the user with delete-and-reinstall as their only
        // option, which destroys the local collection. That state is exactly
        // what an interrupted full-download or import leaves behind.
        //
        // checkDatabase() is also gone from the launch path: it is one of the
        // longest blocking calls the engine has, and running it before the
        // first frame made cold launch scale with collection size. It remains
        // available as an explicit action in Settings > Maintenance.
        do {
            try prepareDependencies {
                let backend = try AnkiBackend(preferredLangs: ["en"])
                try openCollection(for: activeProfile.id, backend: backend)
                $0.ankiBackend = backend
                $0.syncCoordinator = SyncCoordinator()
                // Wire the Anki-backed concrete realization of the dictionary
                // engine's abstract config store. Keeps the engine package
                // (ReaderDictionary) free of Anki imports.
                $0.dictionaryConfigStore = AnkiBackedDictionaryConfigStore.makeStore()
            }
        } catch {
            startupError = error.localizedDescription
        }
    }
}
