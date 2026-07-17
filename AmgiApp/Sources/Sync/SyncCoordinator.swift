import Foundation
import SwiftUI
import UIKit
import AnkiClients
import AnkiKit
import AnkiSync
import Dependencies
import Sharing

@Observable @MainActor
final class SyncCoordinator {
    enum SyncState: Sendable, Equatable {
        case idle
        case syncing(message: String)
        case syncingMedia(total: Int, downloaded: Int)
        case success(SyncSummary)
        case error(String)
        case needsFullSync(SyncFullSyncRequirement)
        case noServer
    }

    private(set) var state: SyncState = .idle
    private(set) var logEntries: [SyncLogEntry] = []
    private(set) var requiresLogin: Bool = false

    var lastSuccessfulSync: Date? {
        lastSyncedAtUnix > 0 ? Date(timeIntervalSince1970: lastSyncedAtUnix) : nil
    }

    @ObservationIgnored @Dependency(\.syncClient) var syncClient
    @ObservationIgnored private var activeTask: Task<Void, Never>?
    @ObservationIgnored private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    @ObservationIgnored
    @Shared(.appStorage(SyncPreferences.Keys.lastCollectionSyncedAtForCurrentUser()))
    private var lastSyncedAtUnix: Double = 0

    @ObservationIgnored
    @Shared(.appStorage(SyncPreferences.Keys.needsFullSyncForCurrentUser()))
    private var needsFullSyncFlag: Bool = false

    private static let logCap = 100

    init() {
        registerLifecycleObservers()
    }

    private func registerLifecycleObservers() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.beginBackgroundExecutionIfNeeded()
            }
        }
        center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.endBackgroundExecutionIfNeeded()
            }
        }

        if needsFullSyncFlag {
            state = .needsFullSync(SyncFullSyncRequirement(
                reason: "A full sync was requested previously and not yet completed",
                localIsEmpty: false
            ))
        }
    }

    private func beginBackgroundExecutionIfNeeded() {
        let isSyncing: Bool
        switch state {
        case .syncing, .syncingMedia: isSyncing = true
        default: isSyncing = false
        }
        guard isSyncing, backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "AmgiSync") { [weak self] in
            // System forced expiration — end task and let cancel() handle state.
            Task { @MainActor in
                self?.endBackgroundExecutionIfNeeded()
                self?.cancel()
            }
        }
        appendLog("Backgrounded mid-sync — extending execution window")
    }

    private func endBackgroundExecutionIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
        appendLog("Foreground resumed — released BG task")
    }

    // MARK: - Public surface (stubs filled in Phase B)

    func startSync() async {
        guard activeTask == nil else {
            appendLog("Sync already in progress", level: .warning)
            return
        }

        clearLog()
        state = .syncing(message: "Connecting…")
        appendLog("Starting sync")

        let task = Task { [weak self] in
            guard let self else { return }
            let client = await self.syncClient
            do {
                let summary = try await client.sync()
                await MainActor.run {
                    self.appendLog("Sync complete: \(summary.cardsPushed) pushed, \(summary.cardsPulled) pulled")
                    self.state = .success(summary)
                    self.$lastSyncedAtUnix.withLock { $0 = Date().timeIntervalSince1970 }
                    self.$needsFullSyncFlag.withLock { $0 = false }
                    self.activeTask = nil
                }
            } catch let error as SyncError where error == .fullSyncRequired {
                await MainActor.run {
                    self.appendLog("Server requires a full sync", level: .warning)
                    self.state = .needsFullSync(SyncFullSyncRequirement(
                        reason: "Schema mismatch — choose upload or download",
                        localIsEmpty: false
                    ))
                    self.$needsFullSyncFlag.withLock { $0 = true }
                    self.activeTask = nil
                }
            } catch let error as SyncError where error == .authFailed {
                await MainActor.run {
                    self.appendLog("Authentication failed", level: .error)
                    self.requiresLogin = true
                    self.state = .error("Authentication failed — please sign in again")
                    self.activeTask = nil
                }
            } catch {
                await MainActor.run {
                    // If activeTask is nil the sync was cancelled — don't overwrite state.
                    guard self.activeTask != nil else { return }
                    self.appendLog("Sync failed: \(error.localizedDescription)", level: .error)
                    self.state = .error(error.localizedDescription)
                    self.activeTask = nil
                }
            }
        }
        activeTask = task
    }

    func confirmFullSync(direction: SyncDirection) async {
        guard case .needsFullSync = state else {
            appendLog("Cannot confirm full sync — not in needsFullSync state", level: .warning)
            return
        }

        let label = direction == .upload ? "Uploading collection" : "Downloading collection"
        state = .syncing(message: label)
        appendLog("Full sync started: \(direction == .upload ? "upload" : "download")")

        let task = Task { [weak self] in
            guard let self else { return }
            let client = await self.syncClient
            do {
                try await client.fullSync(direction)
                await MainActor.run {
                    self.appendLog("Full sync complete")
                    self.state = .success(SyncSummary())
                    self.$lastSyncedAtUnix.withLock { $0 = Date().timeIntervalSince1970 }
                    self.$needsFullSyncFlag.withLock { $0 = false }
                    self.activeTask = nil
                }
            } catch {
                await MainActor.run {
                    guard self.activeTask != nil else { return }
                    self.appendLog("Full sync failed: \(error.localizedDescription)", level: .error)
                    self.state = .error(error.localizedDescription)
                    self.activeTask = nil
                }
            }
        }
        activeTask = task
    }

    func signOut() async {
        cancel()
        KeychainHelper.deleteEndpoint()
        KeychainHelper.deleteHostKey()
        KeychainHelper.deleteUsername()
        appendLog("Signed out")
        state = .noServer
        requiresLogin = false
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        if case .syncing = state {
            appendLog("Sync cancelled", level: .warning)
            state = .idle
        } else if case .syncingMedia = state {
            appendLog("Media sync cancelled", level: .warning)
            state = .idle
        }
    }

    // MARK: - Log helpers (used by all behaviors)

    func appendLog(_ message: String, level: SyncLogEntry.Level = .info) {
        let entry = SyncLogEntry(message: message, level: level)
        logEntries.append(entry)
        if logEntries.count > Self.logCap {
            logEntries.removeFirst(logEntries.count - Self.logCap)
        }
    }

    func clearLog() {
        logEntries.removeAll()
    }
}

private enum SyncCoordinatorKey: DependencyKey {
    nonisolated(unsafe) static let liveValue: SyncCoordinator = MainActor.assumeIsolated { SyncCoordinator() }
    nonisolated(unsafe) static let testValue: SyncCoordinator = MainActor.assumeIsolated { SyncCoordinator() }
}

extension DependencyValues {
    var syncCoordinator: SyncCoordinator {
        get { self[SyncCoordinatorKey.self] }
        set { self[SyncCoordinatorKey.self] = newValue }
    }
}
