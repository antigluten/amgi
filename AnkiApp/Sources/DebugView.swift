import SwiftUI
import AnkiBackend
import AnkiProto
import AnkiSync
import Dependencies
import Foundation
import SwiftProtobuf

struct DebugView: View {
    @Dependency(\.ankiBackend) var backend
    @State private var statusMessage = ""
    @State private var showResetConfirm = false
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        List {
            Section("Account") {
                HStack {
                    Text("Username")
                    Spacer()
                    Text(KeychainHelper.loadUsername() ?? "Not logged in")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Host Key")
                    Spacer()
                    Text(KeychainHelper.loadHostKey() != nil ? "Stored ✓" : "None")
                        .foregroundStyle(.secondary)
                }
                Button("Logout (clear credentials)", role: .destructive) {
                    KeychainHelper.deleteHostKey()
                    statusMessage = "Logged out. Tap sync to re-login."
                }
            }

            Section("Import / Export") {
                Button("Export Collection (.colpkg)") {
                    do {
                        let url = try ImportHelper.exportCollection()
                        exportedFileURL = url
                        showShareSheet = true
                        statusMessage = "Export ready: \(url.lastPathComponent)"
                    } catch {
                        statusMessage = "Export error: \(error.localizedDescription)"
                    }
                }
            }

            Section("Database") {
                Button("Check Database") {
                    do {
                        let responseBytes = try backend.call(service: 2, method: 0)
                        statusMessage = "CheckDatabase OK (\(responseBytes.count) bytes)"
                    } catch {
                        statusMessage = "CheckDatabase error: \(error)"
                    }
                }

                Button("Reset Everything", role: .destructive) {
                    showResetConfirm = true
                }
                .confirmationDialog("This will delete your local collection and credentials. You'll need to sync again.", isPresented: $showResetConfirm, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) {
                        resetEverything()
                    }
                }
            }

            if !statusMessage.isEmpty {
                Section("Status") {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Collection Info") {
                Button("Dump Deck Tree") {
                    dumpDeckTree()
                }
            }
        }
        .navigationTitle("Debug")
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func dumpDeckTree() {
        do {
            var req = Anki_Decks_DeckTreeRequest()
            req.now = Int64(Date().timeIntervalSince1970)

            let responseBytes = try backend.call(
                service: AnkiBackend.Service.decks,
                method: AnkiBackend.DecksMethod.getDeckTree,
                request: req
            )

            let tree = try Anki_Decks_DeckTreeNode(serializedBytes: responseBytes)
            var info = "Root: id=\(tree.deckID), name='\(tree.name)', children=\(tree.children.count)\n"
            for child in tree.children {
                info += "  [\(child.deckID)] \(child.name) — new:\(child.newCount) learn:\(child.learnCount) review:\(child.reviewCount)\n"
                for sub in child.children {
                    info += "    [\(sub.deckID)] \(sub.name)\n"
                }
            }
            statusMessage = info
            print("[Debug] DeckTree:\n\(info)")
        } catch {
            statusMessage = "DeckTree error: \(error)"
            print("[Debug] DeckTree error: \(error)")
        }
    }

    private func resetEverything() {
        // Clear keychain
        KeychainHelper.deleteHostKey()

        // Close collection
        try? backend.closeCollection()

        // Delete database files
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let ankiDir = appSupport.appendingPathComponent("AnkiCollection", isDirectory: true)
        try? FileManager.default.removeItem(at: ankiDir)

        // Remove migration marker so it recreates fresh
        statusMessage = "Reset complete. Please restart the app."
    }
}
