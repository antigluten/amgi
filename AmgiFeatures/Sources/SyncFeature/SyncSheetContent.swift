//
//  SyncSheetContent.swift
//  SyncFeature
//
//  Created by Vladimir Gusev on 27.03.2026.
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

// MARK: - Content

/// Pure render surface for the sync sheet — no `@Dependency`, no data
/// loading. Every dynamic value arrives as a `let`; every action is a
/// closure the Container fulfils.
struct SyncSheetContent: View {
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
    /// When the current sync began, so the waiting state can show elapsed
    /// time. The engine exposes no progress for `sync()` (only `merge()`
    /// takes a progress callback), so an honest "still running, 14s in" is
    /// the most this screen can truthfully say — better than a frozen label
    /// the user cannot distinguish from a wedged app.
    @State private var syncStartedAt: Date?

    private var isSyncing: Bool {
        if case .syncing = state { return true }
        return false
    }

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
            .navigationTitle(String(localized: "Sync", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done", bundle: .module)) { onDone() }
                }
            }
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch state {
        case .idle:
            idleView
        case .syncing(let message):
            syncingView(message)
        case .success(let summary):
            successView(summary)
        case .error(let message):
            errorView(message)
        case .needsFullSync(let requirement):
            fullSyncChoiceView(requirement.reason)
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
                        Text("Server", bundle: .module)
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Menu {
                        Button(String(localized: "Change Server", bundle: .module)) { onChangeServer() }
                        Button(String(localized: "Logout", bundle: .module), role: .destructive) { onLogout() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(palette.textSecondary)
                    }
                    .accessibilityLabel(String(localized: "Account actions", bundle: .module))
                }
                .padding(.horizontal)
            } else if syncMode == .local {
                HStack {
                    Label(String(localized: "Syncing is disabled", bundle: .module), systemImage: "iphone")
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(String(localized: "Set Up Server", bundle: .module)) { onSetUpServer() }
                        .amgiFont(.caption)
                }
                .padding(.horizontal)
            }
        }
    }

    /// Not a spinner. `.idle` means nothing is happening, and
    /// `ProgressView("Preparing sync...")` sat here spinning forever saying
    /// otherwise.
    @ViewBuilder
    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(palette.textSecondary)
            Text(lastSyncedLabel)
                .amgiFont(.body)
                .foregroundStyle(palette.textSecondary)
            Button(String(localized: "Sync Now", bundle: .module)) { onStartSync() }
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func syncingView(_ message: String) -> some View {
        VStack(spacing: 10) {
            ProgressView(message)
            if let syncStartedAt {
                Text(syncStartedAt, style: .timer)
                    .amgiFont(.caption, .monospaced)
                    .foregroundStyle(palette.textSecondary)
                    .accessibilityLabel(String(localized: "Sync running", bundle: .module))
            }
            // The sync is not tied to this sheet's lifetime, and users who
            // think it is sit and watch it.
            Text("You can close this \u{2014} syncing continues.", bundle: .module)
                .amgiFont(.micro)
                .foregroundStyle(palette.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var noServerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(palette.textSecondary)
            Text("No Server Configured", bundle: .module)
                .amgiFont(.sectionHeading)
            Text("Set up a sync server to keep your collection in sync across devices.", bundle: .module)
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "Set Up Server", bundle: .module)) { onSetUpServer() }
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
                                    .amgiFont(.micro, .monospaced)
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
                        withAnimation(AmgiMotion.standard) { proxy.scrollTo(last.id, anchor: .bottom) }
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(String(localized: "Retry", bundle: .module)) { onRetryFooter() }
                        .amgiFont(.captionBold)
                }
            }
        }
    }

    private func fullSyncChoiceView(_ reason: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(palette.warning)
            Text("Full Sync Required", bundle: .module)
                .amgiFont(.sectionHeading)
            Text(reason)
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Button {
                    onMerge()
                } label: {
                    VStack(spacing: 2) {
                        Label(String(localized: "Merge (combine both)", bundle: .module), systemImage: "arrow.triangle.merge")
                            .frame(maxWidth: .infinity)
                        Text("Keeps cards from both sides; conflicts use newest", bundle: .module)
                            .amgiFont(.micro)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    pendingDestructiveChoice = .download
                } label: {
                    VStack(spacing: 2) {
                        Label(String(localized: "Replace local with server", bundle: .module), systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                        Text("Local-only changes will be lost", bundle: .module)
                            .amgiFont(.micro)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    pendingDestructiveChoice = .upload
                } label: {
                    VStack(spacing: 2) {
                        Label(String(localized: "Replace server with local", bundle: .module), systemImage: "arrow.up.circle")
                            .frame(maxWidth: .infinity)
                        Text("Server-only changes will be lost", bundle: .module)
                            .amgiFont(.micro)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .confirmationDialog(
            String(localized: "This cannot be undone", bundle: .module),
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
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        } message: { choice in
            Text(destructiveDialogMessage(choice))
        }
        .onChange(of: isSyncing) { _, syncing in
            syncStartedAt = syncing ? .now : nil
        }
        .onAppear { if isSyncing, syncStartedAt == nil { syncStartedAt = .now } }
    }

    private func destructiveButtonLabel(_ choice: SyncDirection) -> String {
        switch choice {
        case .download: return String(localized: "Replace Local", bundle: .module)
        case .upload: return String(localized: "Replace Server", bundle: .module)
        }
    }

    private func destructiveDialogMessage(_ choice: SyncDirection) -> String {
        switch choice {
        case .download:
            return String(localized: "Your local collection will be permanently overwritten with the server's copy. Any cards or reviews that exist only locally will be lost.", bundle: .module)
        case .upload:
            return String(localized: "The server's collection will be permanently overwritten with your local copy. Any cards or reviews that exist only on the server will be lost.", bundle: .module)
        }
    }

    @ViewBuilder
    private func successView(_ summary: SyncSummary) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(palette.positive)
            Text("Sync Complete", bundle: .module)
                .amgiFont(.sectionHeading)
            VStack(alignment: .leading, spacing: 4) {
                if summary.cardsPulled > 0 { Text("\u{2193} \(summary.cardsPulled) cards received", bundle: .module) }
                if summary.cardsPushed > 0 { Text("\u{2191} \(summary.cardsPushed) cards sent", bundle: .module) }
                if summary.notesPulled > 0 { Text("\u{2193} \(summary.notesPulled) notes received", bundle: .module) }
                if summary.notesPushed > 0 { Text("\u{2191} \(summary.notesPushed) notes sent", bundle: .module) }
                if summary.cardsPulled == 0 && summary.cardsPushed == 0 {
                    Text("Everything up to date", bundle: .module)
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
            Text("Sync Failed", bundle: .module)
                .amgiFont(.sectionHeading)
            Text(message)
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "Retry", bundle: .module)) { onStartSync() }
                .buttonStyle(.borderedProminent)
        }
    }

    func color(for level: SyncLogEntry.Level) -> Color {
        switch level {
        case .info: return palette.textPrimary
        case .warning: return palette.warning
        case .error: return palette.danger
        }
    }
}
