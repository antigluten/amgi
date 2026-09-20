//
//  ServerSetupSheet.swift
//  SyncFeature
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import UI
import SwiftUI
import Theme
import AppCore
import AnkiKit
import AnkiClients
import AnkiSync
import Dependencies
import Sharing

// MARK: - Server Setup Sheet

struct ServerSetupSheet: View {
    @Binding var isPresented: Bool
    let onComplete: () -> Void

    @Shared(.syncMode) private var syncMode

    @State private var serverURL: String = KeychainHelper.loadEndpoint() ?? ""
    @State private var endpointError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Server URL", text: $serverURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    if let endpointError {
                        Text(endpointError)
                            .amgiStatusText(.danger, font: .caption)
                    }
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

extension ServerSetupSheet {
    func save() {
        do {
            let url = try SyncEndpoint.normalized(serverURL)
            try KeychainHelper.saveEndpoint(url)
            endpointError = nil
            $syncMode.withLock { $0 = .custom }
            // Clear existing auth since server changed
            KeychainHelper.deleteHostKey()
            KeychainHelper.deleteCurrentEndpoint()
            isPresented = false
            onComplete()
        } catch {
            endpointError = error.localizedDescription
        }
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
        state: .needsFullSync(.diverged),
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
