import Foundation
import SwiftUI
import UIKit
import AmgiAppCore
import AmgiAppShared
import AnkiClients
import AnkiKit
import AnkiSync
package import Dependencies

@Observable @MainActor
package final class SyncCoordinator {
    enum SyncState: Sendable, Equatable {
        case idle
        case syncing(message: String)
        /// Assigned only from `waitForMediaCompletion`, carrying the engine's
        /// own localized progress line. It was previously declared and never
        /// assigned — a progress state that could not occur — and was
        /// removed for that reason; the engine can supply real progress now.
        case syncingMedia(String)
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
    /// Set by `cancel()`. Distinct from `activeTask` because cancellation is
    /// advisory — the in-flight FFI call still runs to completion, so the
    /// task handle has to stay put to keep the re-entry gate shut.
    @ObservationIgnored private var isCancelling = false
    @ObservationIgnored private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    @ObservationIgnored private var lifecycleObservers: [any NSObjectProtocol] = []
    /// How often `waitForMediaCompletion` re-reads the engine's media
    /// status. Injectable so tests don't pay the real interval.
    @ObservationIgnored private let mediaPollInterval: Duration

    // Profile-scoped persisted state. Computed per access — the key embeds
    // the active profile id, and this coordinator is a singleton that
    // outlives in-app profile switches, so the key must never be captured.
    private var lastSyncedAtUnix: Double {
        get { UserDefaults.standard.double(forKey: SyncPreferences.Keys.lastCollectionSyncedAtForCurrentUser()) }
        set { UserDefaults.standard.set(newValue, forKey: SyncPreferences.Keys.lastCollectionSyncedAtForCurrentUser()) }
    }

    private var needsFullSyncFlag: Bool {
        get { UserDefaults.standard.bool(forKey: SyncPreferences.Keys.needsFullSyncForCurrentUser()) }
        set { UserDefaults.standard.set(newValue, forKey: SyncPreferences.Keys.needsFullSyncForCurrentUser()) }
    }

    private static let logCap = 100

    /// Nonisolated so `SyncCoordinatorKey`'s lazy statics can be initialized
    /// from any thread — a `static let` is initialized by whichever thread
    /// touches it first, so the old `MainActor.assumeIsolated` would abort
    /// the process on first resolution from a detached task or background
    /// test. Observer registration is main-actor work, so it hops.
    package nonisolated init(mediaPollInterval: Duration = .milliseconds(250)) {
        self.mediaPollInterval = mediaPollInterval
        Task { @MainActor [self] in registerLifecycleObservers() }
    }

    /// `isolated deinit` so the observer tokens can be plain main-actor state
    /// instead of `nonisolated(unsafe)` — a nonisolated `deinit` was the only
    /// thing reading them from off the actor, and it is the only reason the
    /// array carried an unchecked escape hatch.
    ///
    /// Tokens from addObserver(forName:object:queue:) were previously
    /// discarded, so the observers outlived any non-singleton instance
    /// and kept calling into a dead coordinator.
    isolated deinit {
        for token in lifecycleObservers {
            NotificationCenter.default.removeObserver(token)
        }
    }

    /// Consumes a pending cancellation: resets state to idle and returns
    /// true if `cancel()` was called while this operation was in flight.
    private func finishCancellationIfNeeded() -> Bool {
        guard isCancelling else { return false }
        isCancelling = false
        appendLog("Sync cancelled", level: .warning)
        // Not over `.noServer`: `signOut()` cancels the in-flight sync and
        // *then* sets `.noServer`, so this completion lands afterwards and
        // would otherwise report a signed-out coordinator as merely idle —
        // i.e. as still having a server configured.
        if case .noServer = state {} else { state = .idle }
        return true
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
            let client = self.syncClient
            do {
                let summary = try await client.sync()
                // `syncCollection` kicks media off in the background and
                // returns immediately; without this the sheet claimed
                // success while media was still downloading.
                let mediaFailure = try await self.awaitMediaCompletion(using: client)
                // Recorded even when media failed: the collection is
                // already committed by this point, and letting one bad
                // media file roll the timestamp back made the next sync
                // look overdue and the last one look lost.
                self.lastSyncedAtUnix = Date().timeIntervalSince1970
                self.needsFullSyncFlag = false
                self.activeTask = nil
                self.isCancelling = false
                self.report(mediaFailure: mediaFailure, otherwise: summary)
                // Sync can change counts without any review — refresh widgets
                // or they keep showing the pre-sync collection.
                await writeWidgetSnapshot()
            } catch let error as SyncError where error == .fullSyncRequired {
                self.appendLog("Server requires a full sync", level: .warning)
                self.state = .needsFullSync(SyncFullSyncRequirement(
                    reason: "Schema mismatch — choose upload or download",
                    localIsEmpty: false
                ))
                self.needsFullSyncFlag = true
                self.activeTask = nil
                self.isCancelling = false
            } catch let error as SyncError where error == .authFailed {
                self.appendLog("Authentication failed", level: .error)
                self.requiresLogin = true
                self.state = .error("Authentication failed — please sign in again")
                self.activeTask = nil
                self.isCancelling = false
            } catch {
                self.activeTask = nil
                // A cancelled sync shouldn't surface as a failure.
                guard !self.finishCancellationIfNeeded() else { return }
                self.appendLog("Sync failed: \(error.localizedDescription)", level: .error)
                self.state = .error(error.localizedDescription)
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
            let client = self.syncClient
            do {
                try await client.fullSync(direction)
                let mediaFailure = try await self.awaitMediaCompletion(using: client)
                self.lastSyncedAtUnix = Date().timeIntervalSince1970
                self.needsFullSyncFlag = false
                self.activeTask = nil
                self.isCancelling = false
                self.report(mediaFailure: mediaFailure, otherwise: SyncSummary())
                // A full download replaces the whole collection — widgets are
                // guaranteed stale without a rewrite.
                await writeWidgetSnapshot()
            } catch {
                self.activeTask = nil
                guard !self.finishCancellationIfNeeded() else { return }
                self.appendLog("Full sync failed: \(error.localizedDescription)", level: .error)
                self.state = .error(error.localizedDescription)
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

    /// Called after an in-app profile switch, once the scoping anchor has
    /// flipped: drop the old profile's transient state and re-derive from
    /// the new profile's persisted flags.
    package func resetForProfileSwitch() {
        cancel()
        clearLog()
        requiresLogin = false
        if needsFullSyncFlag {
            state = .needsFullSync(SyncFullSyncRequirement(
                reason: "A full sync was requested previously and not yet completed",
                localIsEmpty: false
            ))
        } else {
            state = .idle
        }
    }

    /// Requests cancellation. Advisory only.
    ///
    /// The engine call is synchronous Rust FFI with no cancellation hook, so
    /// the RPC runs to completion regardless. What matters is that
    /// `activeTask` is *not* cleared here: doing so re-opened the re-entry
    /// gate in `startSync`, letting a second sync start while the first was
    /// still mutating the collection. Both then serialized behind the
    /// backend lock and a stale full-download could land after a newer
    /// operation — collection-level data loss. The task clears itself when
    /// the in-flight work actually finishes.
    package func cancel() {
        guard activeTask != nil, !isCancelling else { return }
        isCancelling = true
        activeTask?.cancel()
        if case .syncing = state {
            appendLog("Cancelling — finishing the current step in the background", level: .warning)
        } else if case .syncingMedia = state {
            // Media sync *is* abortable in the engine, unlike the collection
            // RPC — so cancelling it actually stops work rather than just
            // hiding it.
            appendLog("Media sync cancelled", level: .warning)
            let client = syncClient
            Task { [weak self] in
                do {
                    try await client.abortMediaSync()
                } catch {
                    self?.appendLog(
                        "Failed to abort media sync: \(error.localizedDescription)",
                        level: .error
                    )
                }
            }
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

private extension SyncCoordinator {
    /// Waits out the media sync and *returns* its failure rather than
    /// throwing it. The collection sync has already committed by the time
    /// this runs, so a media error is a partial failure, not a failed sync,
    /// and must not unwind the caller's success bookkeeping. Cancellation
    /// still propagates — a cancelled sync is not a completed one.
    /// Returns the failure's description, not the error itself — `any Error`
    /// is not `Sendable`, and this result crosses into `MainActor.run`.
    func awaitMediaCompletion(using client: SyncClient) async throws -> String? {
        do {
            try await waitForMediaCompletion(using: client)
            return nil
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return error.localizedDescription
        }
    }

    /// Terminal state for a sync whose collection half succeeded.
    func report(mediaFailure: String?, otherwise summary: SyncSummary) {
        guard let mediaFailure else {
            appendLog("Sync complete: \(summary.cardsPushed) pushed, \(summary.cardsPulled) pulled")
            state = .success(summary)
            return
        }
        appendLog("Collection synced; media sync failed: \(mediaFailure)", level: .error)
        state = .error("Collection synced, but media failed: \(mediaFailure)")
    }

    /// The engine localizes its own progress lines, so they are shown as-is.
    /// Nil until the background task publishes its first snapshot.
    static func mediaProgressMessage(_ progress: MediaSyncProgress?) -> String {
        guard let progress else { return "Syncing media\u{2026}" }
        return "\(progress.checked) \u{00B7} \(progress.added)"
    }

    /// Polls the engine until its background media task reports idle,
    /// publishing each progress snapshot as `.syncingMedia`.
    func waitForMediaCompletion(using client: SyncClient) async throws {
        while true {
            try Task.checkCancellation()
            let status = try await client.mediaSyncStatus()
            guard status.active else { return }

            state = .syncingMedia(Self.mediaProgressMessage(status.progress))
            try await Task.sleep(for: mediaPollInterval)
        }
    }

    func registerLifecycleObservers() {
        let center = NotificationCenter.default
        lifecycleObservers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.beginBackgroundExecutionIfNeeded()
            }
        })
        lifecycleObservers.append(center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.endBackgroundExecutionIfNeeded()
            }
        })

        if needsFullSyncFlag {
            state = .needsFullSync(SyncFullSyncRequirement(
                reason: "A full sync was requested previously and not yet completed",
                localIsEmpty: false
            ))
        }
    }

    func beginBackgroundExecutionIfNeeded() {
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

    func endBackgroundExecutionIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
        appendLog("Foreground resumed — released BG task")
    }
}

private enum SyncCoordinatorKey: DependencyKey {
    static let liveValue = SyncCoordinator()
    static let testValue = SyncCoordinator()
}

extension DependencyValues {
    package var syncCoordinator: SyncCoordinator {
        get { self[SyncCoordinatorKey.self] }
        set { self[SyncCoordinatorKey.self] = newValue }
    }
}
