public import AnkiKit
public import Dependencies
import DependenciesMacros
public import Foundation

@DependencyClient
public struct SyncClient: Sendable {
    public var sync: @Sendable () async throws -> SyncSummary
    public var fullSync: @Sendable (_ direction: SyncDirection) async throws -> Void
    public var syncMedia: @Sendable () async throws -> MediaSyncSummary
    public var lastSyncDate: @Sendable () -> Date? = { nil }

    /// Merge local + server collections by:
    /// 1. exporting local as a temporary .apkg
    /// 2. full-downloading the server's collection (replacing local on disk)
    /// 3. importing the .apkg into the just-downloaded collection
    /// 4. full-uploading the merged result back to the server
    /// 5. deleting the temporary .apkg on success
    ///
    /// Reports progress via the optional callback (e.g. "Backing up local...",
    /// "Downloading from server...", "Merging...", "Uploading merged
    /// collection..."). On partial failure, the temporary .apkg is left on disk
    /// and its path is surfaced in `SyncError.partialMerge`.
    public var merge: @Sendable (_ progress: (@Sendable (String) -> Void)?) async throws -> Void
}

extension SyncClient: TestDependencyKey {
    public static let testValue = SyncClient()
}

extension DependencyValues {
    public var syncClient: SyncClient {
        get { self[SyncClient.self] }
        set { self[SyncClient.self] = newValue }
    }
}
