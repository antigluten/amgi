import AnkiKit
import AnkiServices
import AnkiSync
public import Dependencies
import DependenciesMacros
import Logging

private let logger = Logger(label: "com.ankiapp.sync.client")

extension SyncClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.syncService) var syncService

        return Self(
            sync: {
                let hostKey = KeychainHelper.loadHostKey() ?? ""
                guard !hostKey.isEmpty else { throw SyncError.authFailed }
                let endpoint = KeychainHelper.loadEndpoint() ?? ""
                logger.info("Starting sync")
                return try await syncService.sync(endpoint, hostKey)
            },
            fullSync: { direction in
                let hostKey = KeychainHelper.loadHostKey() ?? ""
                guard !hostKey.isEmpty else { throw SyncError.authFailed }
                let endpoint = KeychainHelper.loadEndpoint() ?? ""
                try await syncService.fullSync(endpoint, hostKey, direction)
            },
            syncMedia: {
                let hostKey = KeychainHelper.loadHostKey() ?? ""
                guard !hostKey.isEmpty else { throw SyncError.authFailed }
                let endpoint = KeychainHelper.loadEndpoint() ?? ""
                try await syncService.syncMedia(endpoint, hostKey)
                return MediaSyncSummary()
            },
            lastSyncDate: { nil }
        )
    }()

    public static func login(
        username: String,
        password: String
    ) async throws -> String {
        @Dependency(\.syncService) var syncService

        logger.info("Logging in as \(username)")
        let endpoint = KeychainHelper.loadEndpoint() ?? ""
        let hostKey = try await syncService.login(endpoint, username, password)
        try KeychainHelper.saveHostKey(hostKey)
        try KeychainHelper.saveUsername(username)
        return hostKey
    }
}
