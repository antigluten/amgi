public import Foundation

public enum SyncDirection: Sendable {
    case upload
    case download
}

public struct SyncError: Error, LocalizedError, Sendable, Equatable {
    public let message: String
    public let isRetryable: Bool

    public init(message: String, isRetryable: Bool = true) {
        self.message = message
        self.isRetryable = isRetryable
    }

    public var errorDescription: String? { message }

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

/// Backend sync credentials. `endpoint` may be rewritten by the
/// backend mid-sync (server redirect) — call sites must use the
/// auth returned in `SyncCollectionResult` for subsequent RPCs.
public struct SyncAuth: Sendable, Equatable {
    public let hkey: String
    public let endpoint: String

    public init(hkey: String, endpoint: String) {
        self.hkey = hkey
        self.endpoint = endpoint
    }
}

/// Mirror of `Anki_Sync_SyncCollectionResponse.ChangesRequired`.
public enum SyncRequiredAction: Sendable, Equatable {
    case noChanges
    case normalSync
    case fullSync
    /// Local collection has no cards — upload is not an option.
    case fullDownload
    /// Remote collection has no cards — download is not an option.
    case fullUpload
    /// An enum case the backend introduced that we don't understand yet.
    case unrecognized(Int)
}

/// Decoded `SyncCollectionResponse`. `newEndpoint` is non-nil only
/// when the backend issued a redirect; callers should rebuild their
/// `SyncAuth` with this value before issuing follow-up RPCs.
public struct SyncCollectionResult: Sendable, Equatable {
    public let required: SyncRequiredAction
    public let newEndpoint: String?
    public let serverMediaUsn: Int32
    public let serverMessage: String

    public init(required: SyncRequiredAction, newEndpoint: String?, serverMediaUsn: Int32, serverMessage: String) {
        self.required = required
        self.newEndpoint = newEndpoint
        self.serverMediaUsn = serverMediaUsn
        self.serverMessage = serverMessage
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
