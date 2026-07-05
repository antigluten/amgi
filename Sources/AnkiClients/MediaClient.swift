public import AnkiKit
public import Foundation
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct MediaClient: Sendable {
    public var localURL: @Sendable (_ filename: String) -> URL? = { _ in nil }
    public var save: @Sendable (_ data: Data, _ filename: String) async throws -> Void
    public var delete: @Sendable (_ filename: String) async throws -> Void

    /// Runs Anki's media-check pass and returns a snapshot of orphan vs. missing media files.
    public var checkMedia: @Sendable () async throws -> MediaCheckResult

    /// Moves named media files into Anki's trash directory (recoverable until emptied).
    public var trashMediaFiles: @Sendable (_ filenames: [String]) async throws -> Void

    /// Permanently deletes everything currently in the media trash.
    public var emptyTrash: @Sendable () async throws -> Void

    /// Restores files in the media trash back into the active media folder.
    public var restoreTrash: @Sendable () async throws -> Void
}

extension MediaClient: TestDependencyKey {
    public static let testValue = MediaClient()
}

extension DependencyValues {
    public var mediaClient: MediaClient {
        get { self[MediaClient.self] }
        set { self[MediaClient.self] = newValue }
    }
}
