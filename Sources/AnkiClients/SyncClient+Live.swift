import AnkiKit
import AnkiBackend
import AnkiProto
import AnkiSync
public import Dependencies
import DependenciesMacros
import Foundation
import Logging
import SwiftProtobuf

private let logger = Logger(label: "com.ankiapp.sync.client")

extension SyncClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend

        return Self(
            sync: {
                let hostKey = KeychainHelper.loadHostKey() ?? ""
                guard !hostKey.isEmpty else { throw SyncError.authFailed }

                logger.info("Starting sync via Rust backend")

                var auth = Anki_Sync_SyncAuth()
                auth.hkey = hostKey

                var req = Anki_Sync_SyncCollectionRequest()
                req.auth = auth
                req.syncMedia = true

                do {
                    let responseBytes = try backend.call(
                        service: AnkiBackend.Service.sync,
                        method: AnkiBackend.SyncMethod.syncCollection,
                        request: req
                    )
                    let response = try Anki_Sync_SyncCollectionResponse(serializedBytes: responseBytes)
                    logger.info("SyncCollection response: required=\(response.required), message='\(response.serverMessage)', endpoint=\(response.newEndpoint)")

                    // Update endpoint if server redirected
                    if response.hasNewEndpoint, !response.newEndpoint.isEmpty {
                        auth.endpoint = response.newEndpoint
                    }

                    switch response.required {
                    case .noChanges:
                        logger.info("No changes needed")
                        return SyncSummary()

                    case .normalSync:
                        logger.info("Normal sync completed by backend")
                        return SyncSummary()

                    case .fullSync, .fullDownload:
                        // Need a full download — local collection is empty or incompatible
                        // The Rust backend internally closes, downloads, and reopens the collection.
                        // We do NOT close beforehand — the backend expects it open.
                        logger.info("Full download required, starting...")
                        var dlReq = Anki_Sync_FullUploadOrDownloadRequest()
                        dlReq.auth = auth
                        dlReq.upload = false
                        dlReq.serverUsn = response.serverMediaUsn

                        try backend.callVoid(
                            service: AnkiBackend.Service.sync,
                            method: AnkiBackend.SyncMethod.fullUploadOrDownload,
                            request: dlReq
                        )
                        logger.info("Full download complete, running CheckDatabase...")

                        // Run CheckDatabase to repair any inconsistencies
                        do {
                            let checkResult = try backend.call(service: 2, method: 0)
                            logger.info("CheckDatabase completed (\(checkResult.count) bytes)")
                        } catch {
                            logger.warning("CheckDatabase failed: \(error) — continuing anyway")
                        }

                        return SyncSummary()

                    case .fullUpload:
                        logger.info("Full upload required, starting...")
                        var ulReq = Anki_Sync_FullUploadOrDownloadRequest()
                        ulReq.auth = auth
                        ulReq.upload = true
                        ulReq.serverUsn = response.serverMediaUsn

                        try backend.callVoid(
                            service: AnkiBackend.Service.sync,
                            method: AnkiBackend.SyncMethod.fullUploadOrDownload,
                            request: ulReq
                        )
                        logger.info("Full upload complete")
                        return SyncSummary()

                    case .UNRECOGNIZED(let v):
                        logger.warning("Unrecognized sync required: \(v)")
                        return SyncSummary()
                    }
                } catch let error as BackendError {
                    logger.error("Sync error: \(error.message)")
                    if error.isSyncAuthError { throw SyncError.authFailed }
                    throw SyncError(message: error.message)
                }
            },
            fullSync: { direction in
                let hostKey = KeychainHelper.loadHostKey() ?? ""
                guard !hostKey.isEmpty else { throw SyncError.authFailed }

                var auth = Anki_Sync_SyncAuth()
                auth.hkey = hostKey

                var req = Anki_Sync_FullUploadOrDownloadRequest()
                req.auth = auth
                req.upload = (direction == .upload)

                do {
                    try backend.callVoid(
                        service: AnkiBackend.Service.sync,
                        method: AnkiBackend.SyncMethod.fullUploadOrDownload,
                        request: req
                    )
                } catch let error as BackendError {
                    if error.isSyncAuthError { throw SyncError.authFailed }
                    throw SyncError(message: error.message)
                }
            },
            syncMedia: {
                let hostKey = KeychainHelper.loadHostKey() ?? ""
                guard !hostKey.isEmpty else { throw SyncError.authFailed }

                var auth = Anki_Sync_SyncAuth()
                auth.hkey = hostKey

                do {
                    try backend.callVoid(
                        service: AnkiBackend.Service.sync,
                        method: AnkiBackend.SyncMethod.syncMedia,
                        request: auth
                    )
                } catch let error as BackendError {
                    if error.isSyncAuthError { throw SyncError.authFailed }
                    throw SyncError(message: error.message)
                }

                return MediaSyncSummary()
            },
            lastSyncDate: { nil }
        )
    }()

    public static func login(
        username: String,
        password: String
    ) async throws -> String {
        @Dependency(\.ankiBackend) var backend

        logger.info("Logging in as \(username)")

        var req = Anki_Sync_SyncLoginRequest()
        req.username = username
        req.password = password

        do {
            let auth: Anki_Sync_SyncAuth = try backend.invoke(
                service: AnkiBackend.Service.sync,
                method: AnkiBackend.SyncMethod.syncLogin,
                request: req
            )

            try KeychainHelper.saveHostKey(auth.hkey)
            try KeychainHelper.saveUsername(username)
            logger.info("Login successful")
            return auth.hkey
        } catch let error as BackendError {
            logger.error("Login failed: \(error.message)")
            throw SyncError.authFailed
        }
    }
}
