import SwiftUI
import AmgiTheme
import AnkiKit
import AnkiClients
import AnkiSync
import Dependencies
import Sharing

/// The distinct render states of the sync sheet. Lifted out of the view so
/// `SyncSheetContent` is a pure function of it and each `#Preview` varies
/// one argument.
enum SyncSheetState {
    case idle
    case syncing(String)
    case success(SyncSummary)
    case error(String)
    case needsFullSync
    case noServer
}

/// Container: owns the sync dependencies, the in-flight `syncState`, and the
/// login/server-setup sheets. Derives plain snapshots (endpoint, log
/// entries, last-synced label) from the engine and hands them to the pure
/// `SyncSheetContent`, translating its callbacks back into engine calls.
struct SyncSheet: View {
    @Binding var isPresented: Bool
    @Dependency(\.syncClient) var syncClient
    @Dependency(\.syncCoordinator) private var coordinator

    @State private var syncState: SyncSheetState = .idle
    @State private var showLogin = false
    @State private var showServerSetup = false
    @Shared(.syncMode) private var syncMode

    var body: some View {
        // Read the endpoint once per render — `body` re-evaluates on every
        // sync-log line (coordinator.logEntries), and isAnkiWeb derives from
        // the same value, so we avoid the extra keychain lookups.
        let endpoint = KeychainHelper.loadEndpoint()
        return SyncSheetContent(
            state: syncState,
            endpoint: endpoint,
            username: KeychainHelper.loadUsername(),
            syncMode: syncMode,
            isAnkiWeb: endpoint?.contains("ankiweb") ?? false,
            logEntries: coordinator.logEntries,
            lastSyncedLabel: lastSyncedLabel,
            footerError: footerError,
            onDone: { isPresented = false },
            onChangeServer: { showServerSetup = true },
            onLogout: { logout() },
            onSetUpServer: { showServerSetup = true },
            onRetryFooter: { Task { await coordinator.startSync() } },
            onStartSync: { Task { await startSync() } },
            onFullSync: { direction in Task { await fullSync(direction) } },
            onMerge: { Task { await mergeFullSync() } }
        )
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

    private var lastSyncedLabel: String {
        guard let last = coordinator.lastSuccessfulSync else { return "Never synced" }
        return "Last synced \(last.formatted(.relative(presentation: .numeric)))"
    }

    private var footerError: String? {
        if case .error(let message) = coordinator.state { return message }
        return nil
    }
}

private extension SyncSheet {
    func startSync() async {
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
            try? await syncClient.syncMedia()
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

    func logout() {
        KeychainHelper.deleteHostKey()
        KeychainHelper.deleteUsername()
        KeychainHelper.deleteCurrentEndpoint()
        syncState = .idle
    }

    func fullSync(_ direction: SyncDirection) async {
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

    func mergeFullSync() async {
        syncState = .syncing("Preparing merge...")
        do {
            try await syncClient.merge { message in
                Task { @MainActor in
                    syncState = .syncing(message)
                }
            }
            syncState = .success(SyncSummary())
        } catch {
            syncState = .error(error.localizedDescription)
        }
    }
}

// MARK: - Content

/// Pure render surface for the sync sheet — no `@Dependency`, no data
/// loading. Every dynamic value arrives as a `let`; every action is a
/// closure the Container fulfils.
private struct SyncSheetContent: View {
    @Environment(\.palette) private var palette

    let state: SyncSheetState
    let endpoint: String?
    let username: String?
    let syncMode: SyncMode
    let isAnkiWeb: Bool
    let logEntries: [SyncLogEntry]
    let lastSyncedLabel: String
    let footerError: String?
    let onDone: () -> Void
    let onChangeServer: () -> Void
    let onLogout: () -> Void
    let onSetUpServer: () -> Void
    let onRetryFooter: () -> Void
    let onStartSync: () -> Void
    let onFullSync: (SyncDirection) -> Void
    let onMerge: () -> Void

    /// Direction awaiting the user's "this cannot be undone" confirmation.
    @State private var pendingDestructiveChoice: SyncDirection?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                serverConfigSection
                    .padding(.top)

                if isAnkiWeb {
                    AnkiMobileAttributionView()
                        .padding(.horizontal)
                }

                Spacer()
                stateView
                Spacer()

                syncLogPanel
                    .padding(.horizontal)
                statusFooter
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDone() }
                }
            }
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch state {
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
    }

    @ViewBuilder
    private var serverConfigSection: some View {
        VStack(spacing: 8) {
            if let endpoint {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Server")
                            .amgiFont(.caption)
                            .foregroundStyle(palette.textSecondary)
                        Text(endpoint)
                            .amgiFont(.caption)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let username {
                            Text(username)
                                .amgiFont(.caption)
                                .foregroundStyle(palette.textTertiary)
                        }
                    }
                    Spacer()
                    Menu {
                        Button("Change Server") { onChangeServer() }
                        Button("Logout", role: .destructive) { onLogout() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .padding(.horizontal)
            } else if syncMode == .local {
                HStack {
                    Label("Syncing is disabled", systemImage: "iphone")
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                    Button("Set Up Server") { onSetUpServer() }
                        .amgiFont(.caption)
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var noServerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(palette.textSecondary)
            Text("No Server Configured")
                .amgiFont(.sectionHeading)
            Text("Set up a sync server to keep your collection in sync across devices.")
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
            Button("Set Up Server") { onSetUpServer() }
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var syncLogPanel: some View {
        if !logEntries.isEmpty {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logEntries) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                    .font(.system(size: AmgiFont.micro.size, weight: AmgiFont.micro.weight, design: .monospaced))
                                    .foregroundStyle(palette.textSecondary)
                                Text(entry.message)
                                    .amgiFont(.caption)
                                    .foregroundStyle(color(for: entry.level))
                            }
                            .id(entry.id)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
                .background(palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: AmgiRadius.small))
                .onChange(of: logEntries.count) { _, _ in
                    if let last = logEntries.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lastSyncedLabel)
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)

            if let footerError {
                HStack {
                    Text(footerError)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.danger)
                    Spacer()
                    Button("Retry") { onRetryFooter() }
                        .amgiFont(.captionBold)
                }
            }
        }
    }

    private var fullSyncChoiceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(palette.warning)
            Text("Full Sync Required")
                .amgiFont(.sectionHeading)
            Text("Your local and server collections have diverged. Choose how to reconcile them — Merge is the safest option.")
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Button {
                    onMerge()
                } label: {
                    VStack(spacing: 2) {
                        Label("Merge (combine both)", systemImage: "arrow.triangle.merge")
                            .frame(maxWidth: .infinity)
                        Text("Keeps cards from both sides; conflicts use newest")
                            .amgiFont(.micro)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    pendingDestructiveChoice = .download
                } label: {
                    VStack(spacing: 2) {
                        Label("Replace local with server", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                        Text("Local-only changes will be lost")
                            .amgiFont(.micro)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    pendingDestructiveChoice = .upload
                } label: {
                    VStack(spacing: 2) {
                        Label("Replace server with local", systemImage: "arrow.up.circle")
                            .frame(maxWidth: .infinity)
                        Text("Server-only changes will be lost")
                            .amgiFont(.micro)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .confirmationDialog(
            "This cannot be undone",
            isPresented: Binding(
                get: { pendingDestructiveChoice != nil },
                set: { if !$0 { pendingDestructiveChoice = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDestructiveChoice
        ) { choice in
            Button(destructiveButtonLabel(choice), role: .destructive) {
                onFullSync(choice)
            }
            Button("Cancel", role: .cancel) {}
        } message: { choice in
            Text(destructiveDialogMessage(choice))
        }
    }

    private func destructiveButtonLabel(_ choice: SyncDirection) -> String {
        switch choice {
        case .download: return "Replace Local"
        case .upload: return "Replace Server"
        }
    }

    private func destructiveDialogMessage(_ choice: SyncDirection) -> String {
        switch choice {
        case .download:
            return "Your local collection will be permanently overwritten with the server's copy. Any cards or reviews that exist only locally will be lost."
        case .upload:
            return "The server's collection will be permanently overwritten with your local copy. Any cards or reviews that exist only on the server will be lost."
        }
    }

    @ViewBuilder
    private func successView(_ summary: SyncSummary) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(palette.positive)
            Text("Sync Complete")
                .amgiFont(.sectionHeading)
            VStack(alignment: .leading, spacing: 4) {
                if summary.cardsPulled > 0 { Text("\u{2193} \(summary.cardsPulled) cards received") }
                if summary.cardsPushed > 0 { Text("\u{2191} \(summary.cardsPushed) cards sent") }
                if summary.notesPulled > 0 { Text("\u{2193} \(summary.notesPulled) notes received") }
                if summary.notesPushed > 0 { Text("\u{2191} \(summary.notesPushed) notes sent") }
                if summary.cardsPulled == 0 && summary.cardsPushed == 0 {
                    Text("Everything up to date")
                }
            }
            .amgiFont(.caption)
            .foregroundStyle(palette.textSecondary)
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(palette.warning)
            Text("Sync Failed")
                .amgiFont(.sectionHeading)
            Text(message)
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") { onStartSync() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func color(for level: SyncLogEntry.Level) -> Color {
        switch level {
        case .info: return palette.textPrimary
        case .warning: return palette.warning
        case .error: return palette.danger
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

}

private extension ServerSetupSheet {
    func save() {
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        try? KeychainHelper.saveEndpoint(url)
        $syncMode.withLock { $0 = .custom }
        // Clear existing auth since server changed
        KeychainHelper.deleteHostKey()
        KeychainHelper.deleteCurrentEndpoint()
        isPresented = false
        onComplete()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Success") {
    SyncSheetContent(
        state: .success(SyncSummary(cardsPushed: 4, cardsPulled: 12, notesPushed: 2, notesPulled: 7)),
        endpoint: "https://sync.example.com",
        username: "vlad",
        syncMode: .custom,
        isAnkiWeb: false,
        logEntries: [],
        lastSyncedLabel: "Last synced 2 minutes ago",
        footerError: nil,
        onDone: {},
        onChangeServer: {},
        onLogout: {},
        onSetUpServer: {},
        onRetryFooter: {},
        onStartSync: {},
        onFullSync: { _ in },
        onMerge: {}
    )
}

#Preview("No server") {
    SyncSheetContent(
        state: .noServer,
        endpoint: nil,
        username: nil,
        syncMode: .local,
        isAnkiWeb: false,
        logEntries: [],
        lastSyncedLabel: "Never synced",
        footerError: nil,
        onDone: {},
        onChangeServer: {},
        onLogout: {},
        onSetUpServer: {},
        onRetryFooter: {},
        onStartSync: {},
        onFullSync: { _ in },
        onMerge: {}
    )
}

#Preview("Full sync required") {
    SyncSheetContent(
        state: .needsFullSync,
        endpoint: "https://sync.example.com",
        username: "vlad",
        syncMode: .custom,
        isAnkiWeb: false,
        logEntries: [],
        lastSyncedLabel: "Last synced yesterday",
        footerError: "Previous sync failed",
        onDone: {},
        onChangeServer: {},
        onLogout: {},
        onSetUpServer: {},
        onRetryFooter: {},
        onStartSync: {},
        onFullSync: { _ in },
        onMerge: {}
    )
}
#endif
