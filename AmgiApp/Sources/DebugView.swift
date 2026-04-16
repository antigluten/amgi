import SwiftUI
import AnkiBackend
import AnkiServices
import AnkiSync
import Dependencies
import Foundation

struct DebugView: View {
    @Dependency(\.ankiBackend) var backend
    @Dependency(\.collectionService) var collectionService
    @Dependency(\.decksService) var decksService
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
                        try collectionService.checkDatabase()
                        statusMessage = "CheckDatabase OK"
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
            let tree = try decksService.fetchTree()
            var info = "\(tree.count) top-level decks\n"
            for node in tree {
                info += "  [\(node.id)] \(node.name) — new:\(node.counts.newCount) learn:\(node.counts.learnCount) review:\(node.counts.reviewCount)\n"
                for sub in node.children {
                    info += "    [\(sub.id)] \(sub.name)\n"
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
        KeychainHelper.deleteHostKey()
        try? backend.closeCollection()
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let ankiDir = appSupport.appendingPathComponent("AnkiCollection", isDirectory: true)
        try? FileManager.default.removeItem(at: ankiDir)
        statusMessage = "Reset complete. Please restart the app."
    }
}
