//
//  BackupView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import SwiftUI
import Theme
import AppCore
import AnkiBackend
import AnkiServices
import Dependencies
import CasePaths
import SwiftNavigation
import SwiftUINavigation

/// Local `.colpkg` backups of the active profile's collection. Each backup
/// is a timestamped copy stored under `Documents/Backups for <profile>/`.
/// The user can create, share (AirDrop / Files / Mail) and delete them.
struct BackupView: View {
    @Dependency(\.importExportService) private var importExportService
    let username: String

    @State private var backups: [BackupEntry] = []
    @State private var isCreating = false
    @State private var destination: Destination?

    /// One axis for all three alerts. As three flag+payload pairs these could
    /// encode states the screen can't render — a raised flag with no message,
    /// or success and error asking to show at once.
    @CasePathable
    enum Destination {
        case confirmDelete(BackupEntry)
        case success(String)
        case failure(String)
    }

    @Environment(\.palette) private var palette

    struct BackupEntry: Identifiable {
        let id = UUID()
        let url: URL
        let date: Date
        // Precomputed once in `loadBackups()` — these used to be computed
        // properties that hit the filesystem / allocated a DateFormatter on
        // every row redraw.
        let formattedDate: String
        let fileSize: String
    }

    var body: some View {
        List {
            createSection
            if backups.isEmpty {
                emptySection
            } else {
                listSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .navigationTitle("Backups")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(BackupAlerts(destination: $destination, onDelete: deleteBackup))
        .task { loadBackups() }
    }

    private var createSection: some View {
        Section {
            Button {
                Task { await createBackup() }
            } label: {
                HStack(spacing: AmgiSpacing.md) {
                    SettingsIconTile(systemImage: "externaldrive.badge.plus", tone: .accent)
                    Text(isCreating ? "Creating backup…" : "Create backup now")
                        .amgiFont(.body)
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: AmgiSpacing.sm)
                    if isCreating { ProgressView() }
                }
            }
            .disabled(isCreating)
            .listRowBackground(palette.surfaceElevated)
        } footer: {
            Text("Backups live in this device's Documents folder for the current profile. Use Share to copy a backup to Files, iCloud Drive, or another device.")
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var emptySection: some View {
        Section {
            Text("No backups yet. Use “Create backup now” above to make one.")
                .amgiFont(.body)
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, AmgiSpacing.sm)
                .listRowBackground(palette.surfaceElevated)
        }
    }

    private var listSection: some View {
        Section {
            ForEach(backups) { entry in
                BackupRow(entry: entry, accent: palette.accent)
                    .listRowBackground(palette.surfaceElevated)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            destination = .confirmDelete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        } header: {
            SettingsListHeader("Available backups")
        }
    }

    // MARK: - Filesystem
}

private extension BackupView {
    func backupsDirectory() -> URL? {
        guard let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return nil }
        let folderName = "Backups for \(username)"
        let dir = docs.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func loadBackups() {
        guard let dir = backupsDirectory() else { return }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        )) ?? []
        backups = files
            .filter { $0.pathExtension == "colpkg" || $0.pathExtension == "anki2" }
            .map { url in
                let values = try? url.resourceValues(
                    forKeys: [.contentModificationDateKey, .fileSizeKey]
                )
                let date = values?.contentModificationDate ?? .distantPast
                let bytes = Int64(values?.fileSize ?? 0)
                return BackupEntry(
                    url: url,
                    date: date,
                    formattedDate: date.formatted(date: .abbreviated, time: .shortened),
                    fileSize: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                )
            }
            .sorted { $0.date > $1.date }
    }

    func createBackup() async {
        isCreating = true
        defer { isCreating = false }
        do {
            guard let dir = backupsDirectory() else {
                throw NSError(
                    domain: "BackupView",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot access backup directory."]
                )
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = formatter.string(from: .now)
            let destURL = dir.appendingPathComponent("\(timestamp).colpkg")
            // Export through the engine rather than copying collection.anki2.
            // The collection is open in WAL mode, so a raw file copy captured
            // neither the -wal sidecar nor a checkpoint — the backup could be
            // a torn or stale snapshot that fails to open, discovered exactly
            // when the user needs it. .colpkg is also what Anki itself uses,
            // so these restore by import on desktop too.
            let outPath = destURL.path
            let service = importExportService
            try await backendOffload {
                try service.exportCollectionPackage(outPath, true)
            }
            loadBackups()
            destination = .success("Saved \(destURL.lastPathComponent).")
        } catch {
            destination = .failure(error.localizedDescription)
        }
    }

    func deleteBackup(_ entry: BackupEntry) {
        try? FileManager.default.removeItem(at: entry.url)
        loadBackups()
    }
}

private struct BackupRow: View {
    let entry: BackupView.BackupEntry
    let accent: Color

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: AmgiSpacing.md) {
            SettingsIconTile(systemImage: "clock.arrow.circlepath", tone: .mature)
            VStack(alignment: .leading, spacing: AmgiSpacing.xxs) {
                Text(entry.formattedDate)
                    .amgiFont(.body)
                    .foregroundStyle(palette.textPrimary)
                Text(entry.fileSize)
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ShareLink(item: entry.url) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share backup from \(entry.formattedDate)")
        }
    }
}

private struct BackupAlerts: ViewModifier {
    @Binding var destination: BackupView.Destination?
    let onDelete: (BackupView.BackupEntry) -> Void

    private var pendingDelete: BackupView.BackupEntry? {
        if case .confirmDelete(let entry) = destination { return entry }
        return nil
    }

    private var successMessage: String? {
        if case .success(let message) = destination { return message }
        return nil
    }

    private var failureMessage: String? {
        if case .failure(let message) = destination { return message }
        return nil
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Delete backup?",
                isPresented: Binding($destination.confirmDelete),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { entry in
                Button("Delete", role: .destructive) { onDelete(entry) }
                Button("Cancel", role: .cancel) {}
            } message: { entry in
                Text("Delete the backup from \(entry.formattedDate)?")
            }
            .alert("Backup saved", isPresented: Binding($destination.success)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(successMessage ?? "")
            }
            .alert("Couldn't create backup", isPresented: Binding($destination.failure)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failureMessage ?? "")
            }
    }
}

#if DEBUG

// MARK: - Preview

#Preview {
    NavigationStack { BackupView(username: "you@example.com") }
}
#endif
