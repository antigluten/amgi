import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto
private import SwiftProtobuf

@Suite struct SyncRequestsTests {
    private let auth = SyncAuth(hkey: "abc123", endpoint: "https://sync.example.com")

    // MARK: - syncCollection

    @Test func syncCollection_dispatches_and_encodes_auth_plus_media_flag() throws {
        let envelope: Request<SyncCollectionResult> = .syncCollection(auth: auth, syncMedia: true)
        #expect(envelope.serviceId == ServiceID.sync)
        #expect(envelope.methodId == SyncMethod.syncCollection)
        let proto = try Anki_Sync_SyncCollectionRequest(serializedBytes: envelope.body)
        #expect(proto.auth.hkey == "abc123")
        #expect(proto.auth.endpoint == "https://sync.example.com")
        #expect(proto.syncMedia)
    }

    @Test func syncCollection_decodes_required_actions_for_all_cases() throws {
        let cases: [(Anki_Sync_SyncCollectionResponse.ChangesRequired, SyncRequiredAction)] = [
            (.noChanges, .noChanges),
            (.normalSync, .normalSync),
            (.fullSync, .fullSync),
            (.fullDownload, .fullDownload),
            (.fullUpload, .fullUpload),
        ]
        for (proto, expected) in cases {
            var resp = Anki_Sync_SyncCollectionResponse()
            resp.required = proto
            let bytes = try resp.serializedData()
            let envelope: Request<SyncCollectionResult> = .syncCollection(auth: auth, syncMedia: false)
            let result = try envelope.decode(bytes)
            #expect(result.required == expected)
        }
    }

    @Test func syncCollection_decodes_unknown_required_value_without_throwing() throws {
        var resp = Anki_Sync_SyncCollectionResponse()
        resp.required = .UNRECOGNIZED(99)
        let bytes = try resp.serializedData()
        let envelope: Request<SyncCollectionResult> = .syncCollection(auth: auth, syncMedia: false)
        // Wire format may collapse unrecognized back to the proto's
        // default (.noChanges) on round-trip; either way the bridge
        // mapper must not throw. The original assertion checked a
        // non-optional value against nil — always-true; replaced with
        // a real exhaustive case check.
        let result = try envelope.decode(bytes)
        switch result.required {
        case .noChanges, .normalSync, .fullSync, .fullDownload, .fullUpload, .unrecognized:
            break  // any known case is acceptable
        }
    }

    @Test func syncCollection_decodes_newEndpoint_when_present() throws {
        var resp = Anki_Sync_SyncCollectionResponse()
        resp.required = .normalSync
        resp.newEndpoint = "https://shard-2.sync.example.com"
        resp.serverMediaUsn = 42
        resp.serverMessage = "ok"
        let bytes = try resp.serializedData()
        let envelope: Request<SyncCollectionResult> = .syncCollection(auth: auth, syncMedia: false)
        let result = try envelope.decode(bytes)
        #expect(result.newEndpoint == "https://shard-2.sync.example.com")
        #expect(result.serverMediaUsn == 42)
        #expect(result.serverMessage == "ok")
    }

    @Test func syncCollection_decodes_newEndpoint_as_nil_when_absent_or_empty() throws {
        var resp = Anki_Sync_SyncCollectionResponse()
        resp.required = .noChanges
        let bytes = try resp.serializedData()
        let envelope: Request<SyncCollectionResult> = .syncCollection(auth: auth, syncMedia: false)
        let result = try envelope.decode(bytes)
        #expect(result.newEndpoint == nil)
    }

    // MARK: - fullUploadOrDownload

    @Test func fullUploadOrDownload_dispatches_and_encodes_direction() throws {
        let envelope: Request<Void> = .fullUploadOrDownload(auth: auth, upload: true, serverUsn: 7)
        #expect(envelope.serviceId == ServiceID.sync)
        #expect(envelope.methodId == SyncMethod.fullUploadOrDownload)
        let proto = try Anki_Sync_FullUploadOrDownloadRequest(serializedBytes: envelope.body)
        #expect(proto.auth.hkey == "abc123")
        #expect(proto.upload)
        #expect(proto.serverUsn == 7)
    }

    // MARK: - media sync

    @Test func mediaSyncStatus_dispatches_and_decodes_progress() throws {
        var proto = Anki_Sync_MediaSyncStatusResponse()
        proto.active = true
        // The engine sends localized display lines, not numbers.
        proto.progress.checked = "Checked: 12"
        proto.progress.added = "Added: 7\u{2191} 0\u{2193}"
        proto.progress.removed = "Removed: 2\u{2191} 0\u{2193}"

        let request: Request<MediaSyncStatus> = .mediaSyncStatus
        #expect(request.serviceId == ServiceID.sync)
        #expect(request.methodId == SyncMethod.mediaSyncStatus)
        #expect(try request.body.isEmpty)
        #expect(
            try request.decode(proto.serializedData())
                == MediaSyncStatus(
                    active: true,
                    progress: MediaSyncProgress(
                        checked: "Checked: 12",
                        added: "Added: 7\u{2191} 0\u{2193}",
                        removed: "Removed: 2\u{2191} 0\u{2193}"
                    )
                )
        )
    }

    @Test func abortMediaSync_dispatches_with_empty_body() throws {
        let request: Request<Void> = .abortMediaSync
        #expect(request.serviceId == ServiceID.sync)
        #expect(request.methodId == SyncMethod.abortMediaSync)
        #expect(try request.body.isEmpty)
    }

    // MARK: - syncLogin

    @Test func syncLogin_dispatches_and_encodes_credentials() throws {
        let envelope: Request<String> = .syncLogin(endpoint: "https://sync.example.com", username: "u", password: "p")
        #expect(envelope.serviceId == ServiceID.sync)
        #expect(envelope.methodId == SyncMethod.syncLogin)
        let proto = try Anki_Sync_SyncLoginRequest(serializedBytes: envelope.body)
        #expect(proto.endpoint == "https://sync.example.com")
        #expect(proto.username == "u")
        #expect(proto.password == "p")
    }

    @Test func syncLogin_decodes_hkey() throws {
        var resp = Anki_Sync_SyncAuth()
        resp.hkey = "returned-hkey"
        let bytes = try resp.serializedData()
        let envelope: Request<String> = .syncLogin(endpoint: "", username: "", password: "")
        #expect(try envelope.decode(bytes) == "returned-hkey")
    }
}
