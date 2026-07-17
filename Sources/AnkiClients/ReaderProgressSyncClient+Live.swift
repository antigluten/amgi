import AmgiReader
import AnkiBackend
public import Dependencies
import DependenciesMacros
import Foundation

extension ReaderProgressSyncClient: DependencyKey {
    /// Anki collection-config key matching DreamAfar's. Keep stable so a
    /// collection that has been read from either fork sees the same
    /// progress data.
    private static let collectionConfigKey = "amgi.reader.progress"

    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend

        return Self(
            loadManifest: {
                try backend.getConfigJSONValue(for: collectionConfigKey)
            },
            pushBookProgress: { bookID, payload in
                var manifest: ReaderProgressManifest = (try backend.getConfigJSONValue(for: collectionConfigKey))
                    ?? ReaderProgressManifest()

                // Last-write-wins per book. The caller stamps `updatedAt`
                // so this routine doesn't need its own clock.
                if let existing = manifest.entries[bookID],
                   existing.updatedAt > payload.updatedAt {
                    return manifest
                }

                manifest.entries[bookID] = payload
                try backend.setConfigJSONValue(manifest, for: collectionConfigKey)
                return manifest
            },
            saveManifest: { manifest in
                try backend.setConfigJSONValue(manifest, for: collectionConfigKey)
            },
            clearManifest: {
                try backend.removeConfigValue(for: collectionConfigKey)
            }
        )
    }()
}
