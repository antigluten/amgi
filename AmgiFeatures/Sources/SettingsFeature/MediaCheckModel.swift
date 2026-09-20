//
//  MediaCheckModel.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 26.06.2026.
//

import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Media-check I/O for the settings screen. Owns the `mediaClient`
/// dependency, the latest check result, the per-action busy flags, and the
/// action-alert state so the view carries no `@Dependency`; the view keeps
/// only the result-rendering layout.
@Observable
@MainActor
final class MediaCheckModel {
    var currentResult: MediaCheckResult?
    var isLoading = true
    var isTrashingUnused = false
    var isDeletingTrash = false
    var isRestoringTrash = false
    var actionMessage: String?
    var showActionAlert = false
    var actionFailed = false

    @ObservationIgnored @Dependency(\.mediaClient) private var mediaClient

    func runMediaCheck() async {
        isLoading = true
        let capturedClient = mediaClient
        do {
            let result = try await Task.detached {
                try await capturedClient.checkMedia()
            }.value
            currentResult = result
        } catch {
            actionMessage = error.localizedDescription
            actionFailed = true
            showActionAlert = true
        }
        isLoading = false
    }

    /// `async` and awaited from the view's Task, so leaving the screen
    /// cancels it. These were untracked `Task.detached`s that kept running
    /// and writing back to the model — repeated taps could start an
    /// unbounded number of overlapping operations, and a stale one could
    /// reset the busy flags. The MainActor.run hops were also redundant:
    /// the model is already @MainActor.
    func trashUnused(filenames: [String]) async {
        isTrashingUnused = true
        defer { isTrashingUnused = false }
        let client = mediaClient
        do {
            try await client.trashMediaFiles(filenames)
            currentResult = try await client.checkMedia()
            actionMessage = "Files moved to trash"
            actionFailed = false
        } catch {
            actionMessage = error.localizedDescription
            actionFailed = true
        }
        showActionAlert = true
    }

    /// `async` and awaited from the view's Task, so leaving the screen
    /// cancels it. These were untracked `Task.detached`s that kept running
    /// and writing back to the model — repeated taps could start an
    /// unbounded number of overlapping operations, and a stale one could
    /// reset the busy flags. The MainActor.run hops were also redundant:
    /// the model is already @MainActor.
    func emptyTrash() async {
        isDeletingTrash = true
        defer { isDeletingTrash = false }
        let client = mediaClient
        do {
            try await client.emptyTrash()
            currentResult = try await client.checkMedia()
            actionMessage = "Trash emptied"
            actionFailed = false
        } catch {
            actionMessage = error.localizedDescription
            actionFailed = true
        }
        showActionAlert = true
    }

    /// `async` and awaited from the view's Task, so leaving the screen
    /// cancels it. These were untracked `Task.detached`s that kept running
    /// and writing back to the model — repeated taps could start an
    /// unbounded number of overlapping operations, and a stale one could
    /// reset the busy flags. The MainActor.run hops were also redundant:
    /// the model is already @MainActor.
    func restoreTrash() async {
        isRestoringTrash = true
        defer { isRestoringTrash = false }
        let client = mediaClient
        do {
            try await client.restoreTrash()
            currentResult = try await client.checkMedia()
            actionMessage = "Trash restored"
            actionFailed = false
        } catch {
            actionMessage = error.localizedDescription
            actionFailed = true
        }
        showActionAlert = true
    }
}
