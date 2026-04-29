import SwiftUI
import AmgiTheme
import AnkiClients
import Dependencies

struct MediaCheckResultView: View {
    @Dependency(\.mediaClient) var mediaClient
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var currentResult: MediaCheckResult?
    @State private var isLoading = true
    @State private var isTrashingUnused = false
    @State private var isDeletingTrash = false
    @State private var isRestoringTrash = false
    @State private var actionMessage: String?
    @State private var showActionAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(palette.background)
                } else if let result = currentResult {
                    contentList(result: result)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Media Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .amgiToolbarTextButton()
                }
            }
            .alert("Done", isPresented: $showActionAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(actionMessage ?? "")
            }
            .task { await runMediaCheck() }
        }
    }

    private func contentList(result: MediaCheckResult) -> some View {
        List {
            summarySection(result: result)
            if !result.missing.isEmpty { missingSection(result: result) }
            if !result.unused.isEmpty { unusedSection(result: result) }
            if result.haveTrash || !result.unused.isEmpty { trashSection(result: result) }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
    }

    private func summarySection(result: MediaCheckResult) -> some View {
        Section("Summary") {
            Label(
                "\(result.missing.count) missing files",
                systemImage: "exclamationmark.triangle"
            )
            .amgiStatusText(result.missing.isEmpty ? .neutral : .danger)
            .listRowBackground(palette.surfaceElevated)

            Label(
                "\(result.unused.count) unused files",
                systemImage: "archivebox"
            )
            .amgiStatusText(result.unused.isEmpty ? .neutral : .warning)
            .listRowBackground(palette.surfaceElevated)

            if !result.report.isEmpty {
                DisclosureGroup("Full report") {
                    Text(result.report)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .listRowBackground(palette.surfaceElevated)
            }
        }
    }

    private func missingSection(result: MediaCheckResult) -> some View {
        Section("Missing files") {
            ForEach(result.missing.prefix(200), id: \.self) { file in
                Label(file, systemImage: "questionmark.circle")
                    .amgiStatusText(.danger, font: .caption)
                    .listRowBackground(palette.surfaceElevated)
            }
            if result.missing.count > 200 {
                Text("…and \(result.missing.count - 200) more")
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .listRowBackground(palette.surfaceElevated)
            }
        }
    }

    private func unusedSection(result: MediaCheckResult) -> some View {
        Section("Unused files") {
            ForEach(result.unused.prefix(200), id: \.self) { file in
                Label(file, systemImage: "tray")
                    .amgiStatusText(.warning, font: .caption)
                    .listRowBackground(palette.surfaceElevated)
            }
            if result.unused.count > 200 {
                Text("…and \(result.unused.count - 200) more")
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .listRowBackground(palette.surfaceElevated)
            }
        }
    }

    private func trashSection(result: MediaCheckResult) -> some View {
        Section("Actions") {
            if !result.unused.isEmpty {
                Button {
                    trashUnused(filenames: result.unused)
                } label: {
                    if isTrashingUnused {
                        HStack {
                            Text("Trash unused files")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Label("Trash unused files", systemImage: "trash")
                    }
                }
                .disabled(isTrashingUnused)
                .listRowBackground(palette.surfaceElevated)
            }

            if result.haveTrash {
                Button {
                    emptyTrash()
                } label: {
                    if isDeletingTrash {
                        HStack {
                            Text("Empty trash")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Label("Empty trash", systemImage: "trash.slash")
                    }
                }
                .disabled(isDeletingTrash)
                .foregroundStyle(palette.danger)
                .listRowBackground(palette.surfaceElevated)

                Button {
                    restoreTrash()
                } label: {
                    if isRestoringTrash {
                        HStack {
                            Text("Restore trash")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Label("Restore trash", systemImage: "arrow.uturn.backward")
                    }
                }
                .disabled(isRestoringTrash)
                .listRowBackground(palette.surfaceElevated)
            }
        }
    }

    private func runMediaCheck() async {
        isLoading = true
        let capturedClient = mediaClient
        do {
            let result = try await Task.detached {
                try capturedClient.checkMedia()
            }.value
            currentResult = result
        } catch {
            actionMessage = error.localizedDescription
            showActionAlert = true
        }
        isLoading = false
    }

    private func trashUnused(filenames: [String]) {
        isTrashingUnused = true
        let capturedClient = mediaClient
        Task.detached {
            do {
                try capturedClient.trashMediaFiles(filenames)
                let latestResult = try capturedClient.checkMedia()
                await MainActor.run {
                    currentResult = latestResult
                    isTrashingUnused = false
                    actionMessage = "Files moved to trash"
                    showActionAlert = true
                }
            } catch {
                await MainActor.run {
                    isTrashingUnused = false
                    actionMessage = error.localizedDescription
                    showActionAlert = true
                }
            }
        }
    }

    private func emptyTrash() {
        isDeletingTrash = true
        let capturedClient = mediaClient
        Task.detached {
            do {
                try capturedClient.emptyTrash()
                let latestResult = try capturedClient.checkMedia()
                await MainActor.run {
                    currentResult = latestResult
                    isDeletingTrash = false
                    actionMessage = "Trash emptied"
                    showActionAlert = true
                }
            } catch {
                await MainActor.run {
                    isDeletingTrash = false
                    actionMessage = error.localizedDescription
                    showActionAlert = true
                }
            }
        }
    }

    private func restoreTrash() {
        isRestoringTrash = true
        let capturedClient = mediaClient
        Task.detached {
            do {
                try capturedClient.restoreTrash()
                let latestResult = try capturedClient.checkMedia()
                await MainActor.run {
                    currentResult = latestResult
                    isRestoringTrash = false
                    actionMessage = "Trash restored"
                    showActionAlert = true
                }
            } catch {
                await MainActor.run {
                    isRestoringTrash = false
                    actionMessage = error.localizedDescription
                    showActionAlert = true
                }
            }
        }
    }
}
