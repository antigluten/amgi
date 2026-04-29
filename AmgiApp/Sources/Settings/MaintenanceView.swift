import SwiftUI
import AnkiBackend
import AnkiServices
import AnkiSync
import Dependencies
import Foundation

struct MaintenanceView: View {
    @Dependency(\.ankiBackend) private var backend
    @Dependency(\.collectionService) private var collectionService

    @State private var statusMessage: String = ""
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section {
                Button("Check Database") { checkDatabase() }
            } footer: {
                Text("Verifies the integrity of your local Anki collection.")
            }

            Section {
                Button("Reset Everything", role: .destructive) {
                    showResetConfirm = true
                }
            } footer: {
                Text("Deletes the local collection and credentials. You will need to sync or re-import after.")
            }

            if !statusMessage.isEmpty {
                Section("Status") {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Maintenance")
        .confirmationDialog(
            "Reset Everything?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { resetEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the local collection database, media, and stored credentials. The action cannot be undone.")
        }
    }

    private func checkDatabase() {
        do {
            try collectionService.checkDatabase()
            statusMessage = "Database check passed"
        } catch {
            statusMessage = "Database check error: \(error.localizedDescription)"
        }
    }

    private func resetEverything() {
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
