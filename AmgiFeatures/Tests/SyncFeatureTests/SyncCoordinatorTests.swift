import Testing
import Foundation
import Dependencies
import Sharing
import AnkiKit
import AnkiClients
@testable import SyncFeature

@Suite("SyncCoordinator state machine")
struct SyncCoordinatorTests {

    @Test @MainActor
    func startSyncWaitsForMediaCompletion() async throws {
        let summary = SyncSummary(cardsPushed: 5, cardsPulled: 3)
        let statuses = MediaStatusQueue([
            MediaSyncStatus(
                active: true,
                progress: MediaSyncProgress(checked: 12, added: 7, removed: 0)
            ),
            MediaSyncStatus(active: false, progress: nil),
        ])
        try await withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
            $0.syncClient.sync = { summary }
            $0.syncClient.mediaSyncStatus = { await statuses.next() }
        } operation: {
            let coordinator = SyncCoordinator(mediaPollInterval: .milliseconds(20))
            await coordinator.startSync()
            try await Task.sleep(for: .milliseconds(10))
            #expect(coordinator.state == .syncingMedia(total: 12, downloaded: 7))
            try await Task.sleep(for: .milliseconds(60))
            guard case .success(let resultSummary) = coordinator.state else {
                Issue.record("expected .success, got \(coordinator.state)")
                return
            }
            #expect(resultSummary == summary)
            #expect(coordinator.lastSuccessfulSync != nil)
        }
    }

    @Test @MainActor
    func mediaSyncErrorTransitionsWithoutRecordingSuccess() async throws {
        try await withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
            $0.syncClient.sync = { SyncSummary() }
            $0.syncClient.mediaSyncStatus = {
                throw SyncError(message: "Media checksum mismatch")
            }
        } operation: {
            let coordinator = SyncCoordinator(mediaPollInterval: .milliseconds(1))
            await coordinator.startSync()
            try await Task.sleep(for: .milliseconds(50))
            guard case .error(let message) = coordinator.state else {
                Issue.record("expected .error, got \(coordinator.state)")
                return
            }
            #expect(message.contains("Media checksum mismatch"))
        }
    }

    @Test @MainActor
    func cancelDuringMediaSyncAbortsBackendTask() async throws {
        let abortRecorder = AsyncFlag()
        try await withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
            $0.syncClient.sync = { SyncSummary() }
            $0.syncClient.mediaSyncStatus = {
                MediaSyncStatus(
                    active: true,
                    progress: MediaSyncProgress(checked: 4, added: 1, removed: 0)
                )
            }
            $0.syncClient.abortMediaSync = { await abortRecorder.set() }
        } operation: {
            let coordinator = SyncCoordinator(mediaPollInterval: .seconds(1))
            await coordinator.startSync()
            try await Task.sleep(for: .milliseconds(50))
            #expect(coordinator.state == .syncingMedia(total: 4, downloaded: 1))
            coordinator.cancel()
            try await Task.sleep(for: .milliseconds(50))
            #expect(coordinator.state == .idle)
            #expect(await abortRecorder.value)
        }
    }

    @Test @MainActor
    func startSyncErrorTransitions() async throws {
        try await withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
            $0.syncClient.sync = {
                throw SyncError(message: "Network unreachable")
            }
        } operation: {
            let coordinator = SyncCoordinator()
            await coordinator.startSync()
            try await Task.sleep(for: .milliseconds(100))
            guard case .error(let message) = coordinator.state else {
                Issue.record("expected .error, got \(coordinator.state)")
                return
            }
            #expect(message.contains("Network unreachable"))
            #expect(coordinator.logEntries.contains { $0.level == .error })
        }
    }

    @Test @MainActor
    func needsFullSyncRequiresUserChoice() async throws {
        try await withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
            $0.syncClient.sync = { throw SyncError.fullSyncRequired }
        } operation: {
            let coordinator = SyncCoordinator()
            await coordinator.startSync()
            try await Task.sleep(for: .milliseconds(100))
            guard case .needsFullSync = coordinator.state else {
                Issue.record("expected .needsFullSync, got \(coordinator.state)")
                return
            }
        }
    }

    @Test @MainActor
    func confirmFullSyncUpload() async throws {
        try await withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
            $0.syncClient.sync = { throw SyncError.fullSyncRequired }
            $0.syncClient.fullSync = { _ in /* success */ }
            $0.syncClient.mediaSyncStatus = { MediaSyncStatus(active: false, progress: nil) }
        } operation: {
            let coordinator = SyncCoordinator()
            await coordinator.startSync()
            try await Task.sleep(for: .milliseconds(100))
            await coordinator.confirmFullSync(direction: .upload)
            try await Task.sleep(for: .milliseconds(100))
            guard case .success = coordinator.state else {
                Issue.record("expected .success after upload, got \(coordinator.state)")
                return
            }
        }
    }

    @Test @MainActor
    func logEntriesCappedAt100() {
        withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
        } operation: {
            let coordinator = SyncCoordinator()
            for i in 0..<200 {
                coordinator.appendLog("entry \(i)")
            }
            #expect(coordinator.logEntries.count == 100)
            #expect(coordinator.logEntries.first?.message == "entry 100")
            #expect(coordinator.logEntries.last?.message == "entry 199")
        }
    }

    @Test @MainActor
    func signOutClearsStateAndCancelsActive() async throws {
        try await withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
            $0.syncClient.sync = {
                try await Task.sleep(for: .milliseconds(500))
                return SyncSummary()
            }
        } operation: {
            let coordinator = SyncCoordinator()
            await coordinator.startSync()
            try await Task.sleep(for: .milliseconds(20))
            await coordinator.signOut()
            try await Task.sleep(for: .milliseconds(100))
            #expect(coordinator.state == .noServer)
            #expect(coordinator.requiresLogin == false)
        }
    }

    @Test @MainActor
    func cancelMidSync() async throws {
        try await withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
            $0.syncClient.sync = {
                try await Task.sleep(for: .milliseconds(500))
                return SyncSummary()
            }
        } operation: {
            let coordinator = SyncCoordinator()
            await coordinator.startSync()
            try await Task.sleep(for: .milliseconds(20))
            coordinator.cancel()
            // `cancel()` is advisory: the Rust FFI call has no cancellation
            // hook, so the coordinator stays `.syncing` and keeps `activeTask`
            // set — clearing it here re-opened the `startSync` re-entry gate
            // and allowed two concurrent syncs. The terminal `.idle` arrives
            // later, from `finishCancellationIfNeeded`.
            #expect(coordinator.state == .syncing(message: "Connecting…"))
            #expect(coordinator.logEntries.contains { $0.message.contains("Cancelling") })

            try await Task.sleep(for: .milliseconds(100))
            #expect(coordinator.state == .idle)
            #expect(coordinator.logEntries.contains { $0.message.contains("cancelled") })
        }
    }

    @Test @MainActor
    func appendLogIncrementsAndOrders() {
        withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
        } operation: {
            let coordinator = SyncCoordinator()
            coordinator.appendLog("first")
            coordinator.appendLog("second", level: .warning)
            coordinator.appendLog("third", level: .error)
            #expect(coordinator.logEntries.count == 3)
            #expect(coordinator.logEntries[0].message == "first")
            #expect(coordinator.logEntries[0].level == .info)
            #expect(coordinator.logEntries[2].level == .error)
        }
    }
}

private actor MediaStatusQueue {
    private var statuses: [MediaSyncStatus]

    init(_ statuses: [MediaSyncStatus]) {
        self.statuses = statuses
    }

    /// Repeats the last entry rather than trapping — the coordinator polls
    /// on its own clock, so the call count isn't fixed.
    func next() -> MediaSyncStatus {
        statuses.count > 1 ? statuses.removeFirst() : statuses[0]
    }
}

private actor AsyncFlag {
    private(set) var value = false

    func set() {
        value = true
    }
}
