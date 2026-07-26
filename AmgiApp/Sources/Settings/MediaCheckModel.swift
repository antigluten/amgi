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

    @ObservationIgnored @Dependency(\.mediaClient) private var mediaClient

    func runMediaCheck() async {
        isLoading = true
        let capturedClient = mediaClient
        do {
            let result = try await Task.detached {
                try capturedClient.checkMedia()
            }.value
            currentResult = result
        } catch {
            actionMessage = error.localizedDescription
            showActionAlert = true
        }
        isLoading = false
    }

    func trashUnused(filenames: [String]) {
        isTrashingUnused = true
        let capturedClient = mediaClient
        Task.detached {
            do {
                try capturedClient.trashMediaFiles(filenames)
                let latestResult = try capturedClient.checkMedia()
                await MainActor.run {
                    self.currentResult = latestResult
                    self.isTrashingUnused = false
                    self.actionMessage = "Files moved to trash"
                    self.showActionAlert = true
                }
            } catch {
                await MainActor.run {
                    self.isTrashingUnused = false
                    self.actionMessage = error.localizedDescription
                    self.showActionAlert = true
                }
            }
        }
    }

    func emptyTrash() {
        isDeletingTrash = true
        let capturedClient = mediaClient
        Task.detached {
            do {
                try capturedClient.emptyTrash()
                let latestResult = try capturedClient.checkMedia()
                await MainActor.run {
                    self.currentResult = latestResult
                    self.isDeletingTrash = false
                    self.actionMessage = "Trash emptied"
                    self.showActionAlert = true
                }
            } catch {
                await MainActor.run {
                    self.isDeletingTrash = false
                    self.actionMessage = error.localizedDescription
                    self.showActionAlert = true
                }
            }
        }
    }

    func restoreTrash() {
        isRestoringTrash = true
        let capturedClient = mediaClient
        Task.detached {
            do {
                try capturedClient.restoreTrash()
                let latestResult = try capturedClient.checkMedia()
                await MainActor.run {
                    self.currentResult = latestResult
                    self.isRestoringTrash = false
                    self.actionMessage = "Trash restored"
                    self.showActionAlert = true
                }
            } catch {
                await MainActor.run {
                    self.isRestoringTrash = false
                    self.actionMessage = error.localizedDescription
                    self.showActionAlert = true
                }
            }
        }
    }
}
