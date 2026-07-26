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

    /// Runs a media-only sync (no collection changes).
    public static func syncMedia(auth: SyncAuth) -> Self {
        Self(
            serviceId: ServiceID.sync,
            methodId: SyncMethod.syncMedia,
            encode: { try Anki_Sync_SyncAuth(auth).serializedData() },
            decode: { _ in () }
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
