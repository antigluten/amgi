//
//  SyncCoordinatorTests.swift
//  SyncFeatureTests
//
//  Created by Vladimir Gusev on 02.05.2026.
//

import Testing
import Foundation
import Dependencies
import Sharing
import AnkiKit
import AnkiClients
import AppCore
@testable import SyncFeature

@Suite("SyncCoordinator state machine", .serialized)
struct SyncCoordinatorTests {

    init() {
        UserDefaults.standard.removeObject(
            forKey: SyncPreferences.Keys.needsFullSyncForCurrentUser()
        )
        UserDefaults.standard.removeObject(
            forKey: SyncPreferences.Keys.lastCollectionSyncedAtForCurrentUser()
        )
    }

    @Test @MainActor
    func startSyncWaitsForMediaCompletion() async throws {
        let summary = SyncSummary(cardsPushed: 5, cardsPulled: 3)
        let statuses = MediaStatusQueue([
            MediaSyncStatus(
                active: true,
                progress: MediaSyncProgress(
                    checked: "Checked: 12",
                    added: "Added: 7\u{2191} 0\u{2193}",
                    removed: "Removed: 0\u{2191} 0\u{2193}"
                )
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
            #expect(coordinator.state == .syncingMedia("Checked: 12 \u{00B7} Added: 7\u{2191} 0\u{2193}"))
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
    func mediaSyncErrorSurfacesButKeepsTheCollectionSyncRecord() async throws {
        try await withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
            $0.syncClient.sync = { SyncSummary() }
            $0.syncClient.mediaSyncStatus = {
                throw SyncError(message: "Media checksum mismatch")
            }
        } operation: {
            let before = Date()
            let coordinator = SyncCoordinator(mediaPollInterval: .milliseconds(1))
            await coordinator.startSync()
            try await Task.sleep(for: .milliseconds(50))
            guard case .error(let message) = coordinator.state else {
                Issue.record("expected .error, got \(coordinator.state)")
                return
            }
            #expect(message.contains("Media checksum mismatch"))
            #expect((coordinator.lastSuccessfulSync ?? .distantPast) >= before)
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
                    progress: MediaSyncProgress(
                        checked: "Checked: 4",
                        added: "Added: 1\u{2191} 0\u{2193}",
                        removed: "Removed: 0\u{2191} 0\u{2193}"
                    )
                )
            }
            $0.syncClient.abortMediaSync = { await abortRecorder.set() }
        } operation: {
            let coordinator = SyncCoordinator(mediaPollInterval: .seconds(1))
            await coordinator.startSync()
            try await Task.sleep(for: .milliseconds(50))
            #expect(coordinator.state == .syncingMedia("Checked: 4 \u{00B7} Added: 1\u{2191} 0\u{2193}"))
            coordinator.cancel()
            try await Task.sleep(for: .milliseconds(50))
            #expect(coordinator.state == .idle)
            #expect(await abortRecorder.value)
        }
    }

    @Test @MainActor
    func cancelAndWaitReturnsAfterThePollLoopAndAbortHaveUnwound() async throws {
        let abortRecorder = AsyncFlag()
        try await withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
            $0.syncClient.sync = { SyncSummary() }
            $0.syncClient.mediaSyncStatus = { MediaSyncStatus(active: true, progress: nil) }
            $0.syncClient.abortMediaSync = { await abortRecorder.set() }
        } operation: {
            let coordinator = SyncCoordinator(mediaPollInterval: .seconds(10))
            await coordinator.startSync()
            try await Task.sleep(for: .milliseconds(50))
            #expect(coordinator.state == .syncingMedia("Syncing media\u{2026}"))
            await coordinator.cancelAndWait()
            #expect(coordinator.state == .idle)
            #expect(await abortRecorder.value)
            // The gate is open again: a new sync may start at once.
            await coordinator.startSync()
            #expect(coordinator.state == .syncing(message: "Connecting…"))
            await coordinator.cancelAndWait()
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
    func fullUploadRequiresUserChoiceAndUploadsNothing() async throws {
        let uploads = UploadRecorder()
        try await withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
            $0.syncClient.sync = { throw SyncError.fullUploadRequired }
            $0.syncClient.fullSync = { _ in await uploads.record() }
        } operation: {
            let coordinator = SyncCoordinator()
            await coordinator.startSync()
            try await Task.sleep(for: .milliseconds(100))
            guard case .needsFullSync(let requirement) = coordinator.state else {
                Issue.record("expected .needsFullSync, got \(coordinator.state)")
                return
            }
            #expect(requirement == .serverEmpty)
            #expect(await uploads.called == false)
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

private actor UploadRecorder {
    private(set) var called = false

    func record() {
        called = true
    }
}

private actor MediaStatusQueue {
    private var statuses: [MediaSyncStatus]

    init(_ statuses: [MediaSyncStatus]) {
        self.statuses = statuses
    }

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
