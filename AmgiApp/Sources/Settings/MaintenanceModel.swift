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

    func checkDatabase() {
        do {
            try collectionService.checkDatabase()
            statusMessage = "Database check passed"
        } catch {
            statusMessage = "Database check error: \(error.localizedDescription)"
        }
    }

    func resetEverything() {
        KeychainHelper.deleteHostKey()
        KeychainHelper.deleteUsername()
        try? backend.closeCollection()
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let ankiDir = appSupport.appendingPathComponent("AnkiCollection", isDirectory: true)
        try? FileManager.default.removeItem(at: ankiDir)
        statusMessage = "Reset complete. Please restart the app."
    }
}
