import AmgiReader
import AnkiBackend
import Dependencies
import Foundation

/// Concrete `DictionaryConfigStore` realization backed by the Anki
/// collection config. Lives in the app target — the package layer
/// (AmgiReaderDictionary) defines the abstract contract, and the app
/// chooses what backs it at runtime.
///
/// Routing the dictionary library config through Anki's collection
/// config means every device that syncs the same collection sees the
/// same dictionary configuration, with no extra sync infrastructure.
enum AnkiBackedDictionaryConfigStore {
    static func makeStore() -> DictionaryConfigStore {
        DictionaryConfigStore(
            load: { key in
                @Dependency(\.ankiBackend) var backend
                return try backend.getConfigRawJSON(for: key)
            },
            save: { json, key in
                @Dependency(\.ankiBackend) var backend
                try backend.setConfigRawJSON(json, for: key)
            },
            remove: { key in
                @Dependency(\.ankiBackend) var backend
                try backend.removeConfigValue(for: key)
            }
        )
    }
}
