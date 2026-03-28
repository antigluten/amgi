import SwiftUI
import AnkiKit
import AnkiClients
import AnkiSync
import Dependencies

struct SyncSheet: View {
    @Binding var isPresented: Bool
    @Dependency(\.syncClient) var syncClient

    @State private var syncState: SyncState = .idle
    @State private var showLogin = false

    enum SyncState {
        case idle
        case syncing(String)
        case success(SyncSummary)
        case error(String)
        case needsFullSync
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
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
        .task { await startSync() }
    }

    private func startSync() async {
        guard KeychainHelper.loadHostKey() != nil else {
            showLogin = true
            return
        }

        syncState = .syncing("Syncing with AnkiWeb...")

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
                    Label("Download from AnkiWeb", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task { await fullSync(.upload) }
                } label: {
                    Label("Upload to AnkiWeb", systemImage: "arrow.up.circle")
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
