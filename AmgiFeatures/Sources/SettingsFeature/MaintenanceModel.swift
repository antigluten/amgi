import AmgiAppCore
import AnkiBackend
import AnkiServices
import AnkiSync
import Dependencies
import Foundation

/// Collection-maintenance I/O for the settings screen. Owns the backend and
/// collection-service dependencies plus the status message so the view
/// carries no `@Dependency`; the reset confirmation-dialog flag stays on the
/// view.
@Observable
@MainActor
final class MaintenanceModel {
    var statusMessage: String = ""

    @ObservationIgnored @Dependency(\.ankiBackend) private var backend
    @ObservationIgnored @Dependency(\.collectionService) private var collectionService

    private(set) var isChecking = false

    func checkDatabase() async {
        isChecking = true
        defer { isChecking = false }
        do {
            // A full-collection integrity check is one of the longest
            // blocking calls the engine has; running it on the main actor
            // froze Settings outright and risked a watchdog kill.
            let service = collectionService
            let problems = try await backendOffload { try service.checkDatabase() }
            // The engine repairs what it finds and reports it here; saying
            // only "passed" hid the fact that anything had been changed.
            statusMessage = problems.isEmpty
                ? "Database check passed"
                : "Database check completed:\n" + problems.joined(separator: "\n")
        } catch {
            statusMessage = "Database check error: \(error.localizedDescription)"
        }
    }

    /// Deletes the **active profile's** collection and credentials.
    ///
    /// Scoped to one profile deliberately. The keychain helpers are
    /// per-profile, so the old whole-`AnkiCollection` delete destroyed every
    /// profile's data while leaving the other profiles' logins and registry
    /// entries intact — the app would restart listing profiles whose data
    /// was gone but whose sync credentials still worked, and the next sync
    /// could push an empty collection up.
    func resetEverything() async {
        let profileID = AccountStore.shared.current.id
        let profileDirectory = AccountStore.profileDirectory(for: profileID)
        let backend = self.backend
        do {
            try await backendOffload { try backend.closeCollection() }
        } catch {
            // Already closed, or never opened — deletion is still correct.
        }
        KeychainHelper.deleteAll(forProfile: profileID)
        do {
            try FileManager.default.removeItem(at: profileDirectory)
            statusMessage = "Reset complete. Please restart the app."
        } catch CocoaError.fileNoSuchFile {
            statusMessage = "Reset complete. Please restart the app."
        } catch {
            // Reporting success on a failed delete left the user believing
            // their data was gone when it was not.
            statusMessage = "Reset failed: \(error.localizedDescription)"
        }
    }
}
