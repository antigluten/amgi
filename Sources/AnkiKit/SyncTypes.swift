import Foundation

public enum SyncDirection: Sendable {
    case upload
    case download
}

public struct SyncError: Error, Sendable, Equatable {
    public let message: String
    public let isRetryable: Bool

    public init(message: String, isRetryable: Bool = true) {
        self.message = message
        self.isRetryable = isRetryable
    }

    public static let authFailed = SyncError(message: "Authentication failed", isRetryable: false)
    public static let networkUnavailable = SyncError(message: "Network unavailable", isRetryable: true)
    public static let fullSyncRequired = SyncError(message: "Full sync required", isRetryable: false)
    public static let conflictDetected = SyncError(message: "Conflict detected", isRetryable: false)
}

public struct SyncSummary: Sendable, Equatable {
    public var cardsPushed: Int
    public var cardsPulled: Int
    public var notesPushed: Int
    public var notesPulled: Int
    public var conflictsResolved: Int

    public init(
        cardsPushed: Int = 0, cardsPulled: Int = 0,
        notesPushed: Int = 0, notesPulled: Int = 0, conflictsResolved: Int = 0
    ) {
        self.cardsPushed = cardsPushed
        self.cardsPulled = cardsPulled
        self.notesPushed = notesPushed
        self.notesPulled = notesPulled
        self.conflictsResolved = conflictsResolved
    }
}

public struct MediaSyncSummary: Sendable, Equatable {
    public var filesUploaded: Int
    public var filesDownloaded: Int
    public var filesDeleted: Int

    public init(filesUploaded: Int = 0, filesDownloaded: Int = 0, filesDeleted: Int = 0) {
        self.filesUploaded = filesUploaded
        self.filesDownloaded = filesDownloaded
        self.filesDeleted = filesDeleted
    }
}
