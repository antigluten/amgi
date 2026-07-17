import AnkiKit
import AnkiServices
import AnkiSync
public import Dependencies
import DependenciesMacros
import Foundation
import Logging

private let logger = Logger(label: "com.ankiapp.sync.client")

/// How long a merge-flow backup is kept before it's considered stale. A failed
/// merge deliberately leaves its backup on disk for recovery; this window is
/// generous enough to cover that while preventing indefinite accumulation.
private let mergeBackupRetention: TimeInterval = 7 * 24 * 60 * 60

/// Path for a merge-flow backup .apkg. Lives in Documents/MergeBackups/ so
/// it survives across app launches if the merge fails partway.
private func makeMergeBackupURL() throws -> URL {
    let documents = try FileManager.default.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let folder = documents.appendingPathComponent("MergeBackups", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    sweepStaleMergeBackups(in: folder)

    let stamp = Int(Date().timeIntervalSince1970)
    return folder.appendingPathComponent("merge-backup-\(stamp).apkg")
}

/// Removes merge-backup-*.apkg files older than `mergeBackupRetention` so failed
/// merges don't pile up tens-of-MB files in the user's Documents. Best-effort:
/// any error sweeping a single file is logged and skipped.
private func sweepStaleMergeBackups(in folder: URL) {
    let fileManager = FileManager.default
    guard let entries = try? fileManager.contentsOfDirectory(
        at: folder,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
    ) else { return }

    let cutoff = Date().addingTimeInterval(-mergeBackupRetention)
    for entry in entries where entry.lastPathComponent.hasPrefix("merge-backup-")
        && entry.pathExtension == "apkg" {
        let modified = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        guard let modified, modified < cutoff else { continue }
        do {
            try fileManager.removeItem(at: entry)
            logger.info("Swept stale merge backup \(entry.lastPathComponent)")
        } catch {
            logger.warning("Failed to sweep stale merge backup \(entry.lastPathComponent): \(error.localizedDescription)")
        }
    }
}

extension SyncClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.syncService) var syncService
        @Dependency(\.importExportService) var importExportService

        return Self(
            sync: {
                let hostKey = KeychainHelper.loadHostKey() ?? ""
                guard !hostKey.isEmpty else { throw SyncError.authFailed }
                let endpoint = KeychainHelper.loadCurrentEndpoint() ?? KeychainHelper.loadEndpoint() ?? ""
                logger.info("Starting sync")
                return try await syncService.sync(endpoint, hostKey)
            },
            fullSync: { direction in
                let hostKey = KeychainHelper.loadHostKey() ?? ""
                guard !hostKey.isEmpty else { throw SyncError.authFailed }
                let endpoint = KeychainHelper.loadCurrentEndpoint() ?? KeychainHelper.loadEndpoint() ?? ""
                try await syncService.fullSync(endpoint, hostKey, direction)
            },
            syncMedia: {
                let hostKey = KeychainHelper.loadHostKey() ?? ""
                guard !hostKey.isEmpty else { throw SyncError.authFailed }
                let endpoint = KeychainHelper.loadCurrentEndpoint() ?? KeychainHelper.loadEndpoint() ?? ""
                try await syncService.syncMedia(endpoint, hostKey)
                return MediaSyncSummary()
            },
            lastSyncDate: { nil },
            merge: { progress in
                let hostKey = KeychainHelper.loadHostKey() ?? ""
                guard !hostKey.isEmpty else { throw SyncError.authFailed }
                let endpoint = KeychainHelper.loadCurrentEndpoint() ?? KeychainHelper.loadEndpoint() ?? ""

                let backupURL = try makeMergeBackupURL()
                let backupPath = backupURL.path

                // Step 1: export local as .apkg backup (no destruction yet, so
                // failure here is safely retryable).
                progress?("Backing up local collection...")
                logger.info("Merge: exporting local backup to \(backupPath)")
                do {
                    try importExportService.exportApkgForMerge(backupPath)
                } catch {
                    try? FileManager.default.removeItem(at: backupURL)
                    throw SyncError(message: "Merge failed during backup: \(error.localizedDescription)")
                }

                // From here on, partial failures leave the backup in place so
                // the user can recover.
                func wrap(_ stage: String, _ work: () async throws -> Void) async throws {
                    do {
                        try await work()
                    } catch {
                        logger.error("Merge failed at \(stage): \(error.localizedDescription)")
                        throw SyncError(
                            message: "Merge failed during \(stage): \(error.localizedDescription). Local backup saved at \(backupPath).",
                            isRetryable: false,
                            recoveryBackupPath: backupPath
                        )
                    }
                }

                progress?("Downloading from server...")
                try await wrap("download") {
                    try await syncService.fullSync(endpoint, hostKey, .download)
                }

                progress?("Merging in local data...")
                try await wrap("merge import") {
                    _ = try importExportService.importApkgForMerge(backupPath)
                }

                progress?("Uploading merged collection...")
                try await wrap("upload") {
                    try await syncService.fullSync(endpoint, hostKey, .upload)
                }

                // Success — clean up.
                try? FileManager.default.removeItem(at: backupURL)
                logger.info("Merge complete")
            }
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
