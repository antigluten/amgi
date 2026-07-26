package import AnkiKit
package import AnkiProto

// MARK: - SyncAuth

package extension Anki_Sync_SyncAuth {
    init(_ auth: SyncAuth) {
        self.init()
        self.hkey = auth.hkey
        self.endpoint = auth.endpoint
    }
}

// MARK: - SyncRequiredAction

package extension SyncRequiredAction {
    init(_ proto: Anki_Sync_SyncCollectionResponse.ChangesRequired) {
        switch proto {
        case .noChanges:        self = .noChanges
        case .normalSync:       self = .normalSync
        case .fullSync:         self = .fullSync
        case .fullDownload:     self = .fullDownload
        case .fullUpload:       self = .fullUpload
        case .UNRECOGNIZED(let v): self = .unrecognized(v)
        }
    }
}

// MARK: - SyncCollectionResult

package extension SyncCollectionResult {
    init(_ proto: Anki_Sync_SyncCollectionResponse) {
        self.init(
            required: SyncRequiredAction(proto.required),
            newEndpoint: (proto.hasNewEndpoint && !proto.newEndpoint.isEmpty) ? proto.newEndpoint : nil,
            serverMediaUsn: proto.serverMediaUsn,
            serverMessage: proto.serverMessage
        )
    }
}

extension SyncCollectionResult: BridgeDecodable {
    package typealias Proto = Anki_Sync_SyncCollectionResponse
}
