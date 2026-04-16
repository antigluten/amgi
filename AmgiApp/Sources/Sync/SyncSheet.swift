import SwiftUI
import AnkiKit
import AnkiClients
import AnkiSync
import Dependencies
import Sharing

struct SyncSheet: View {
    @Binding var isPresented: Bool
    @Dependency(\.syncClient) var syncClient

    @State private var syncState: SyncState = .idle
    @State private var showLogin = false
    @State private var showServerSetup = false
    @Shared(.syncMode) private var syncMode

    enum SyncState {
        case idle
        case syncing(String)
        case success(SyncSummary)
        case error(String)
        case needsFullSync
        case noServer
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                serverConfigSection
                    .padding(.top)

                Spacer()
                switch syncState {
                case .idle:
                    ProgressView("Preparing sync...")
                case .syncing(let message):
                    ProgressView(message)
                case .success(let summary):
                    successView(summary)
                case .error(let message):
                    errorView(message)
                case .needsFullSync:
                    fullSyncChoiceView
                case .noServer:
                    noServerView
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginSheet(isPresented: $showLogin) {
                Task { await startSync() }
            }
        }
        .sheet(isPresented: $showServerSetup) {
            ServerSetupSheet(isPresented: $showServerSetup) {
                Task { await startSync() }
            }
        }
        .task { await startSync() }
    }

    @ViewBuilder
    private var serverConfigSection: some View {
        VStack(spacing: 8) {
            if let endpoint = KeychainHelper.loadEndpoint() {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Server")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(endpoint)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let username = KeychainHelper.loadUsername() {
                            Text(username)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Menu {
                        Button("Change Server") {
                            showServerSetup = true
                        }
                        Button("Logout", role: .destructive) {
                            logout()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            } else if syncMode == .local {
                HStack {
                    Label("Syncing is disabled", systemImage: "iphone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Set Up Server") {
                        showServerSetup = true
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
            }
        }
    }

    private func startSync() async {
        guard KeychainHelper.loadEndpoint() != nil else {
            syncState = .noServer
            return
        }

        guard KeychainHelper.loadHostKey() != nil else {
            showLogin = true
            return
        }

        syncState = .syncing("Syncing...")

        do {
            let summary = try await syncClient.sync()
            syncState = .syncing("Syncing media...")
            _ = try? await syncClient.syncMedia()
            syncState = .success(summary)
        } catch let syncError as SyncError where syncError == .authFailed {
            showLogin = true
            syncState = .idle
        } catch let syncError as SyncError where syncError == .fullSyncRequired {
            syncState = .needsFullSync
        } catch {
            syncState = .error(error.localizedDescription)
        }
    }

    private func logout() {
        KeychainHelper.deleteHostKey()
        KeychainHelper.deleteUsername()
        syncState = .idle
    }

    @ViewBuilder
    private var noServerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Server Configured")
                .font(.title3.weight(.semibold))
            Text("Set up a sync server to keep your collection in sync across devices.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Set Up Server") {
                showServerSetup = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func successView(_ summary: SyncSummary) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Sync Complete")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                if summary.cardsPulled > 0 { Text("\u{2193} \(summary.cardsPulled) cards received") }
                if summary.cardsPushed > 0 { Text("\u{2191} \(summary.cardsPushed) cards sent") }
                if summary.notesPulled > 0 { Text("\u{2193} \(summary.notesPulled) notes received") }
                if summary.notesPushed > 0 { Text("\u{2191} \(summary.notesPushed) notes sent") }
                if summary.cardsPulled == 0 && summary.cardsPushed == 0 {
                    Text("Everything up to date")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Sync Failed")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await startSync() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var fullSyncChoiceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Full Sync Required")
                .font(.title3.weight(.semibold))
            Text("Your collection has changed in a way that requires replacing one copy entirely.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Button {
                    Task { await fullSync(.download) }
                } label: {
                    Label("Download from Server", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task { await fullSync(.upload) }
                } label: {
                    Label("Upload to Server", systemImage: "arrow.up.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func fullSync(_ direction: SyncDirection) async {
        syncState = .syncing(
            direction == .download ? "Downloading collection..." : "Uploading collection..."
        )
        do {
            try await syncClient.fullSync(direction)
            syncState = .success(SyncSummary())
        } catch {
            syncState = .error(error.localizedDescription)
        }
    }
}

// MARK: - Server Setup Sheet

private struct ServerSetupSheet: View {
    @Binding var isPresented: Bool
    let onComplete: () -> Void

    @Shared(.syncMode) private var syncMode

    @State private var serverURL: String = KeychainHelper.loadEndpoint() ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Server URL", text: $serverURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                } header: {
                    Text("Sync Server")
                } footer: {
                    Text("Enter the URL of your Anki sync server (e.g. https://sync.example.com).")
                }

                Section {
                    Button("Save") {
                        save()
                    }
                    .disabled(serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Server Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    private func save() {
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        try? KeychainHelper.saveEndpoint(url)
        $syncMode.withLock { $0 = .custom }
        // Clear existing auth since server changed
        KeychainHelper.deleteHostKey()
        isPresented = false
        onComplete()
    }
}
