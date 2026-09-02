import AmgiUI
import SwiftUI
import AmgiTheme
import AmgiAppCore
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

    init(_ state: SyncCoordinator.SyncState) {
        switch state {
        case .idle:
            self = .idle
        case .syncing(let message):
            self = .syncing(message)
        case .syncingMedia(let message):
            // Same wording as the toast — the two used to disagree, the sheet
            // showing a flat "Syncing media…" while the toast counted files.
            self = .syncing(message)
        case .success(let summary):
            self = .success(summary)
        case .error(let message):
            self = .error(message)
        case .needsFullSync:
            self = .needsFullSync
        case .noServer:
            self = .noServer
        }
    }
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

    init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
    }

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
        .onChange(of: coordinator.state, initial: true) { _, state in
            syncState = SyncSheetState(state)
        }
        // The sheet used to catch `.authFailed` itself; now that the
        // coordinator owns the sync it reports the same thing this way.
        .onChange(of: coordinator.requiresLogin, initial: true) { _, needsLogin in
            if needsLogin { showLogin = true }
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

        // The coordinator owns the state machine — the sheet mirrors it via
        // `onChange`. Running a second sync here raced the coordinator's and
        // hid media progress behind a sheet-local guess.
        await coordinator.startSync()
    }

    func logout() {
        KeychainHelper.deleteHostKey()
        KeychainHelper.deleteUsername()
        KeychainHelper.deleteCurrentEndpoint()
        syncState = .idle
    }

    func fullSync(_ direction: SyncDirection) async {
        await coordinator.confirmFullSync(direction: direction)
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
