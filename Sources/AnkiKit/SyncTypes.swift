public import Foundation

public enum SyncDirection: Sendable {
    case upload
    case download
}

public struct SyncError: Error, LocalizedError, Sendable, Equatable {
    public let message: String
    /// When set, an in-progress merge failed and the local-collection backup
    /// .apkg has been left on disk at this path so the user can recover.
    public let recoveryBackupPath: String?

    public init(message: String, recoveryBackupPath: String? = nil) {
        self.message = message
        self.recoveryBackupPath = recoveryBackupPath
    }

    public var errorDescription: String? { message }

    public static let authFailed = SyncError(message: "Authentication failed")
    public static let fullSyncRequired = SyncError(message: "Full sync required")
}

public struct SyncSummary: Sendable, Equatable {
    public var cardsPushed: Int
    public var cardsPulled: Int
    public var notesPushed: Int
    public var notesPulled: Int

    public init(
        cardsPushed: Int = 0, cardsPulled: Int = 0,
        notesPushed: Int = 0, notesPulled: Int = 0
    ) {
        self.cardsPushed = cardsPushed
        self.cardsPulled = cardsPulled
        self.notesPushed = notesPushed
        self.notesPulled = notesPulled
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

