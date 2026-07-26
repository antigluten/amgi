// AmgiApp/Sources/Sync/SyncToastController.swift
import SwiftUI

/// Owns the bottom sync-toast state machine that used to live inline in
/// `ContentView`. Translates `SyncCoordinator.SyncState` transitions into a
/// `SyncToast.Kind?`, and auto-dismisses the success toast after a beat.
/// Kept off the View so the mapping is testable in isolation.
@Observable
@MainActor
final class SyncToastController {
    private(set) var toast: SyncToast.Kind?

    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    /// Immediate feedback when the user taps Sync, before the coordinator
    /// has had a chance to flip its state.
    func presentSyncing() {
        cancelDismiss()
        toast = .progress("Syncing\u{2026}")
    }

    /// Drive the toast from a coordinator state change.
    func handle(_ state: SyncCoordinator.SyncState) {
        switch state {
        case .syncing(let message):
            cancelDismiss()
            toast = .progress(message.isEmpty ? "Syncing\u{2026}" : message)
        case .syncingMedia(let total, let downloaded):
            cancelDismiss()
            toast = .progress("Media \(downloaded)/\(total)")
        case .success(let summary):
            toast = .success(SyncToast.summaryMessage(for: summary))
            cancelDismiss()
            dismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled { toast = nil }
            }
        case .needsFullSync, .error, .noServer, .idle:
            cancelDismiss()
            toast = nil
        }
    }

    /// Whether a state should pull up the sync sheet for the user.
    static func needsAttention(_ state: SyncCoordinator.SyncState) -> Bool {
        switch state {
        case .needsFullSync, .error: return true
        default: return false
        }
    }

}

private extension SyncToastController {
    func cancelDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }
}

extension View {
    /// Pins the sync toast to the bottom edge with the standard transition
    /// and animation. Lifted out of `ContentView`'s body so the host keeps
    /// a flat modifier chain.
    func syncToastOverlay(_ kind: SyncToast.Kind?) -> some View {
        overlay(alignment: .bottom) {
            if let kind {
                SyncToast(kind: kind)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: kind)
    }
}
