import SwiftUI
import AmgiTheme

/// Local backups of the active profile's `collection.anki2`. Each backup
/// is a timestamped copy stored under `Documents/Backups for <profile>/`.
/// The user can create, share (AirDrop / Files / Mail) and delete them.
struct BackupView: View {
    let username: String

    @State private var backups: [BackupEntry] = []
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var successMessage: String?
    @State private var showSuccess = false
    @State private var backupToDelete: BackupEntry?
    @State private var showDeleteConfirm = false

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
        .modifier(BackupAlerts(
            showDeleteConfirm: $showDeleteConfirm,
            backupToDelete: backupToDelete,
            onDelete: { if let e = backupToDelete { deleteBackup(e) } },
            showSuccess: $showSuccess,
            successMessage: successMessage,
            showError: $showError,
            errorMessage: errorMessage
        ))
        .task { loadBackups() }
    }

    private var createSection: some View {
        Section {
            Button {
                Task { await createBackup() }
            } label: {
                if isCreating {
                    HStack {
                        Label("Creating backup…", systemImage: "externaldrive.badge.plus")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Label("Create backup now", systemImage: "externaldrive.badge.plus")
                }
            }
            .disabled(isCreating)
        } footer: {
            Text("Backups live in this device's Documents folder for the current profile. Use Share to copy a backup to Files, iCloud Drive, or another device.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var emptySection: some View {
        Section {
            Text("No backups yet.")
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        }
    }

    private var listSection: some View {
        Section("Available backups") {
            ForEach(backups) { entry in
                BackupRow(entry: entry, accent: palette.accent)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            backupToDelete = entry
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
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
            .filter { $0.pathExtension == "anki2" }
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
            let sourceURL = AccountStore.profileDirectory(for: AccountStore.shared.current.id)
                .appendingPathComponent("collection.anki2")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = formatter.string(from: .now)
            let destURL = dir.appendingPathComponent("\(timestamp).anki2")
            try await Task.detached(priority: .userInitiated) {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
            }.value
            loadBackups()
            successMessage = "Saved \(destURL.lastPathComponent)."
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
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
        HStack {
            VStack(alignment: .leading, spacing: AmgiSpacing.xxs) {
                Text(entry.formattedDate)
                    .foregroundStyle(palette.textPrimary)
                Text(entry.fileSize)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
            ShareLink(item: entry.url) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct BackupAlerts: ViewModifier {
    @Binding var showDeleteConfirm: Bool
    let backupToDelete: BackupView.BackupEntry?
    let onDelete: () -> Void

    @Binding var showSuccess: Bool
    let successMessage: String?

    @Binding var showError: Bool
    let errorMessage: String?

    func body(content: Content) -> some View {
        content
            .alert("Delete backup?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { onDelete() }
            } message: {
                Text("Delete the backup from \(backupToDelete?.formattedDate ?? "this date")?")
            }
            .alert("Done", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(successMessage ?? "")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { BackupView(username: "you@example.com") }
}
