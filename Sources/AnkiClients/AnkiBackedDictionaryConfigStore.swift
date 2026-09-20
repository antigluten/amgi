//
//  AnkiBackedDictionaryConfigStore.swift
//  AnkiClients
//
//  Created by Vladimir Gusev on 05.05.2026.
//

public import Reader
import AnkiBackend
import Dependencies
import Foundation

/// Concrete `DictionaryConfigStore` realization backed by the Anki
/// collection config. `Reader` defines the abstract contract; this is
/// the Anki-bridged realization, so it lives here alongside
/// `ReaderBookClient` rather than in the app target — the app's only job is
/// to install it at the composition root.
///
/// Routing the dictionary library config through Anki's collection
/// config means every device that syncs the same collection sees the
/// same dictionary configuration, with no extra sync infrastructure.
public enum AnkiBackedDictionaryConfigStore {
    public static func makeStore() -> DictionaryConfigStore {
        DictionaryConfigStore(
            load: { key in
                @Dependency(\.ankiBackend) var backend
                return try backend.getConfigRawJSON(for: key)
            },
            save: { json, key in
                @Dependency(\.ankiBackend) var backend
                try backend.setConfigRawJSON(json, for: key)
            }
        )
    }
}
