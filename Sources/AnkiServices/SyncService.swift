import AnkiBackend
import AnkiProtoBridge
import AnkiSync
public import AnkiKit
public import Dependencies
import DependenciesMacros
import Foundation
import Logging

private let logger = Logger(label: "com.ankiapp.sync.service")

@DependencyClient
public struct SyncService: Sendable {
    public var sync: @Sendable (_ endpoint: String, _ hostKey: String) async throws -> SyncSummary
    public var fullSync: @Sendable (_ endpoint: String, _ hostKey: String, _ direction: SyncDirection) async throws -> Void
    public var syncMedia: @Sendable (_ endpoint: String, _ hostKey: String) async throws -> Void
    public var login: @Sendable (_ endpoint: String, _ username: String, _ password: String) async throws -> String
}

extension SyncService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            sync: { endpoint, hostKey in
                var auth = SyncAuth(hkey: hostKey, endpoint: endpoint)

                do {
                    let result = try backend.invoke(.syncCollection(auth: auth, syncMedia: true))
                    logger.info("SyncCollection: required=\(result.required), message='\(result.serverMessage)'")

                    if let newEndpoint = result.newEndpoint {
                        auth = SyncAuth(hkey: auth.hkey, endpoint: newEndpoint)
                    }

                    switch result.required {
                    case .noChanges, .normalSync:
                        return SyncSummary()

                    case .fullSync, .fullDownload:
                        logger.info("Full download required")
                        try backend.invoke(.fullUploadOrDownload(
                            auth: auth, upload: false, serverUsn: result.serverMediaUsn
                        ))
                        try? backend.checkDatabase()
                        return SyncSummary()

                    case .fullUpload:
                        logger.info("Full upload required")
                        try backend.invoke(.fullUploadOrDownload(
                            auth: auth, upload: true, serverUsn: result.serverMediaUsn
                        ))
                        return SyncSummary()

                    case .unrecognized(let v):
                        logger.warning("Unrecognized sync required: \(v)")
                        return SyncSummary()
                    }
                } catch let error as BackendError {
                    logger.error("Sync error: \(error.message)")
                    if error.isSyncAuthError { throw SyncError.authFailed }
                    throw SyncError(message: error.message)
                }
            },
            fullSync: { endpoint, hostKey, direction in
                let auth = SyncAuth(hkey: hostKey, endpoint: endpoint)
                do {
                    try backend.invoke(.fullUploadOrDownload(
                        auth: auth, upload: direction == .upload, serverUsn: 0
                    ))
                } catch let error as BackendError {
                    if error.isSyncAuthError { throw SyncError.authFailed }
                    throw SyncError(message: error.message)
                }
            },
            syncMedia: { endpoint, hostKey in
                let auth = SyncAuth(hkey: hostKey, endpoint: endpoint)
                do {
                    try backend.invoke(.syncMedia(auth: auth))
                } catch let error as BackendError {
                    if error.isSyncAuthError { throw SyncError.authFailed }
                    throw SyncError(message: error.message)
                }
            },
            login: { endpoint, username, password in
                do {
                    let hkey = try backend.invoke(.syncLogin(
                        endpoint: endpoint, username: username, password: password
                    ))
                    logger.info("Login successful for \(username)")
                    return hkey
                } catch let error as BackendError {
                    logger.error("Login failed: \(error.message)")
                    throw SyncError.authFailed
                }
            }
        )
    }()
}

extension SyncService: TestDependencyKey {
    public static let testValue = SyncService()
}

extension DependencyValues {
    public var syncService: SyncService {
        get { self[SyncService.self] }
        set { self[SyncService.self] = newValue }
    }
}
