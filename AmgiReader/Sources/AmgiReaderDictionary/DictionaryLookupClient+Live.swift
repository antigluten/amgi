import AmgiReader
public import Dependencies
import DependenciesMacros
import Foundation

/// Public liveValue wiring. Deliberately does NOT `import CHoshiDicts` —
/// that import is isolated to `DictionaryLookupRuntime.swift` (internal)
/// so the Cxx-mode requirement doesn't leak into consumers' swiftinterface.
extension DictionaryLookupClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.dictionaryConfigStore) var configStore
        let runtime = DictionaryLookupRuntime(configStore: configStore)

        return Self(
            lookup: { text, maxResults, scanLength in
                try await runtime.lookup(text, maxResults: maxResults, scanLength: scanLength)
            },
            loadStyles: {
                await runtime.loadStyles()
            },
            mediaFile: { dictionary, mediaPath in
                try await runtime.mediaFile(dictionary: dictionary, mediaPath: mediaPath)
            },
            loadState: {
                try await runtime.loadState()
            },
            importArchives: { urls, kind in
                try await runtime.importArchives(urls, kind: kind)
            },
            importRecommended: {
                try await runtime.importRecommended()
            },
            updateDictionaries: {
                try await runtime.updateDictionaries()
            },
            setEnabled: { kind, dictionaryID, enabled in
                try await runtime.setEnabled(kind: kind, dictionaryID: dictionaryID, enabled: enabled)
            },
            delete: { kind, dictionaryID in
                try await runtime.delete(kind: kind, dictionaryID: dictionaryID)
            },
            reorder: { kind, dictionaryIDs in
                try await runtime.reorder(kind: kind, dictionaryIDs: dictionaryIDs)
            }
        )
    }()
}
