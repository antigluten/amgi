public import AmgiReader
public import Dependencies
import DependenciesMacros

/// Cross-device sync adapter for `ReaderProgressStore`. The store persists
/// per-book progress locally to UserDefaults; this client mirrors writes
/// into the Anki collection config so the same progress reaches other
/// devices via Anki sync.
///
/// Lives in `AnkiClients` rather than `AmgiReader` because the bridge
/// to Anki's `setConfigJSONValue` is an Anki concern. `AmgiReader` itself
/// stays Anki-free.
@DependencyClient
public struct ReaderProgressSyncClient: Sendable {
    /// Returns the merged manifest of book → progress entries that the
    /// Anki collection currently holds, or nil if nothing has been
    /// synced yet from any device.
    public var loadManifest: @Sendable () throws -> ReaderProgressManifest?
    /// Pushes a single book's progress into the collection config and
    /// returns the resulting manifest. Idempotent on identical writes.
    public var pushBookProgress: @Sendable (
        _ bookID: String,
        _ payload: ReaderSavedProgress
    ) throws -> ReaderProgressManifest
    /// Replaces the manifest wholesale — used by tests and by the
    /// optional "reset reader sync" maintenance action.
    public var saveManifest: @Sendable (_ manifest: ReaderProgressManifest) throws -> Void
    /// Removes the reader-progress key from the Anki collection config.
    public var clearManifest: @Sendable () throws -> Void
}

extension ReaderProgressSyncClient: TestDependencyKey {
    public static let testValue = ReaderProgressSyncClient()
}

extension DependencyValues {
    public var readerProgressSyncClient: ReaderProgressSyncClient {
        get { self[ReaderProgressSyncClient.self] }
        set { self[ReaderProgressSyncClient.self] = newValue }
    }
}

/// JSON-encoded shape stored in the Anki collection config under the
/// `amgi.reader.progress` key. Mirrors DreamAfar's manifest schema so a
/// collection synced between forks can interoperate.
public struct ReaderProgressManifest: Codable, Sendable, Equatable {
    public var version: Int
    public var entries: [String: ReaderSavedProgress]

    public init(version: Int = 1, entries: [String: ReaderSavedProgress] = [:]) {
        self.version = version
        self.entries = entries
    }
}
