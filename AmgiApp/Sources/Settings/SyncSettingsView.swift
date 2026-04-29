import SwiftUI
import AmgiTheme
import AnkiSync
import Sharing

struct SyncSettingsView: View {
    @Shared(.syncMode) private var syncMode
    @State private var endpoint: String? = KeychainHelper.loadEndpoint()
    @State private var username: String? = KeychainHelper.loadUsername()
    @State private var isLoggedIn: Bool = KeychainHelper.loadHostKey() != nil
    @State private var showServerSetup = false
    @State private var showDisableConfirm = false

    var body: some View {
        Form {
            if let endpoint {
                Section("Server") {
                    LabeledContent("URL") {
                        Text(endpoint).truncationMode(.middle).lineLimit(1)
                    }
                }

                Section("Account") {
                    LabeledContent("Username") {
                        Text(username ?? "Not signed in")
                            .foregroundStyle(username == nil ? .secondary : .primary)
                    }
                    LabeledContent("Credentials") {
                        Text(isLoggedIn ? "Stored" : "Not signed in")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Change Server") { showServerSetup = true }
                    Button("Logout", role: .destructive) { logout() }
                        .disabled(!isLoggedIn)
                }

                Section {
                    Button("Disable Sync (Local Only)", role: .destructive) {
                        showDisableConfirm = true
                    }
                } footer: {
                    Text("Stops syncing. Your local collection is unaffected.")
                }
            } else {
                Section {
                    Label("Sync is disabled", systemImage: "iphone")
                        .foregroundStyle(.secondary)
                    Button("Set Up Server") { showServerSetup = true }
                }
            }
        }
        .navigationTitle("Sync Server")
        .sheet(isPresented: $showServerSetup) {
            ServerSetupView {
                endpoint = KeychainHelper.loadEndpoint()
                username = KeychainHelper.loadUsername()
                isLoggedIn = KeychainHelper.loadHostKey() != nil
            }
        }
        .confirmationDialog(
            "Disable Sync?",
            isPresented: $showDisableConfirm,
            titleVisibility: .visible
        ) {
            Button("Disable", role: .destructive) { disableSync() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes the server, credentials, and switches the app to local-only mode.")
        }
    }

    private func logout() {
        KeychainHelper.deleteHostKey()
        KeychainHelper.deleteUsername()
        username = nil
        isLoggedIn = false
    }

    private func disableSync() {
        KeychainHelper.deleteHostKey()
        KeychainHelper.deleteUsername()
        KeychainHelper.deleteEndpoint()
        $syncMode.withLock { $0 = .local }
        endpoint = nil
        username = nil
        isLoggedIn = false
    }
}

private struct ServerSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Shared(.syncMode) private var syncMode
    @State private var url: String = KeychainHelper.loadEndpoint() ?? ""
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://sync.example.com", text: $url)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                } header: {
                    Text("Sync Server URL")
                } footer: {
                    Text("Enter the URL of your Anki-compatible sync server.")
                }

                Section {
                    Button("Save", action: save)
                        .disabled(trimmed.isEmpty)
                }
            }
            .navigationTitle("Sync Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var trimmed: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        var normalized = trimmed
        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://" + normalized
        }
        try? KeychainHelper.saveEndpoint(normalized)
        $syncMode.withLock { $0 = .custom }
        KeychainHelper.deleteHostKey()  // force re-auth on next sync
        onSave()
        dismiss()
    }
}
