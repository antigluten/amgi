public import Foundation
public import Dependencies
import DependenciesMacros

public struct MediaCheckResult: Sendable {
    public let missing: [String]
    public let unused: [String]
    public let missingNoteIDs: [Int64]
    public let report: String
    public let haveTrash: Bool

    public init(
        missing: [String],
        unused: [String],
        missingNoteIDs: [Int64],
        report: String,
        haveTrash: Bool
    ) {
        self.missing = missing
        self.unused = unused
        self.missingNoteIDs = missingNoteIDs
        self.report = report
        self.haveTrash = haveTrash
    }
}

@DependencyClient
public struct MediaClient: Sendable {
    public var localURL: @Sendable (_ filename: String) -> URL? = { _ in nil }
    public var save: @Sendable (_ data: Data, _ filename: String) throws -> Void
    public var delete: @Sendable (_ filename: String) throws -> Void

    /// Runs Anki's media-check pass and returns a snapshot of orphan vs. missing media files.
    public var checkMedia: @Sendable () throws -> MediaCheckResult

    /// Moves named media files into Anki's trash directory (recoverable until emptied).
    public var trashMediaFiles: @Sendable (_ filenames: [String]) throws -> Void

    /// Permanently deletes everything currently in the media trash.
    public var emptyTrash: @Sendable () throws -> Void

    /// Restores files in the media trash back into the active media folder.
    public var restoreTrash: @Sendable () throws -> Void
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
