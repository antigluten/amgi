import Foundation
public import AnkiBackend
public import AnkiKit
import AnkiProto
import SwiftProtobuf

// MARK: - syncCollection

extension Request where Response == SyncCollectionResult {
    /// Runs an incremental sync. The response indicates whether a full
    /// sync is needed in either direction; callers chain into
    /// `fullUploadOrDownload` accordingly.
    public static func syncCollection(auth: SyncAuth, syncMedia: Bool) -> Self {
        .decoded(
            serviceId: ServiceID.sync,
            methodId: SyncMethod.syncCollection,
            encode: {
                var proto = Anki_Sync_SyncCollectionRequest()
                proto.auth = Anki_Sync_SyncAuth(auth)
                proto.syncMedia = syncMedia
                return try proto.serializedData()
            }
        )
    }
}

// MARK: - fullUploadOrDownload

extension Request where Response == Void {
    /// Forces a full upload or download. `upload: true` pushes the local
    /// collection to the server; `false` replaces local with the server's.
    /// `serverUsn` should come from the preceding `syncCollection` result.
    public static func fullUploadOrDownload(auth: SyncAuth, upload: Bool, serverUsn: Int32) -> Self {
        Self(
            serviceId: ServiceID.sync,
            methodId: SyncMethod.fullUploadOrDownload,
            encode: {
                var proto = Anki_Sync_FullUploadOrDownloadRequest()
                proto.auth = Anki_Sync_SyncAuth(auth)
                proto.upload = upload
                proto.serverUsn = serverUsn
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Requests cancellation of an active media sync.
    public static var abortMediaSync: Self {
        .empty(
            serviceId: ServiceID.sync,
            methodId: SyncMethod.abortMediaSync,
            decode: { _ in () }
        )
    }
}

extension Request where Response == MediaSyncStatus {
    /// Returns active media-sync state and its latest progress snapshot.
    /// A completed background task may surface its terminal error here.
    public static var mediaSyncStatus: Self {
        .empty(
            serviceId: ServiceID.sync,
            methodId: SyncMethod.mediaSyncStatus,
            decode: { bytes in
                let proto = try Anki_Sync_MediaSyncStatusResponse(serializedBytes: bytes)
                let progress = proto.hasProgress
                    ? MediaSyncProgress(
                        checked: proto.progress.checked,
                        added: proto.progress.added,
                        removed: proto.progress.removed
                    )
                    : nil
                return MediaSyncStatus(active: proto.active, progress: progress)
            }
        )
    }
}

// MARK: - syncLogin

extension Request where Response == String {
    /// Exchanges username/password for a host key (`hkey`). The returned
    /// string is the credential value to embed in subsequent `SyncAuth`s.
    public static func syncLogin(endpoint: String, username: String, password: String) -> Self {
        Self(
            serviceId: ServiceID.sync,
            methodId: SyncMethod.syncLogin,
            encode: {
                var proto = Anki_Sync_SyncLoginRequest()
                proto.endpoint = endpoint
                proto.username = username
                proto.password = password
                return try proto.serializedData()
            },
            decode: { bytes in
                try Anki_Sync_SyncAuth(serializedBytes: bytes).hkey
            }
        )
    }
}
