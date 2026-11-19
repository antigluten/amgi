//
//  MediaCheckResultView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 29.04.2026.
//

import SwiftUI
import Theme
import UI
import AnkiClients
import AnkiKit
import Dependencies

struct MediaCheckResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var model = MediaCheckModel()
    @State private var showEmptyTrashConfirm = false

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.background)
            } else if let result = model.currentResult {
                contentList(result: result)
            } else {
                ContentUnavailableView {
                    Label(String(localized: "Media Check Unavailable", bundle: .module), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(model.actionMessage ?? String(localized: "Couldn't read the media database.", bundle: .module))
                } actions: {
                    Button(String(localized: "Try Again", bundle: .module)) { Task { await model.runMediaCheck() } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.background)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .navigationTitle(String(localized: "Media Check", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            Text(model.actionFailed ? "Couldn't update media" : "Media updated", bundle: .module),
            isPresented: $model.showActionAlert
        ) {
            Button(String(localized: "OK", bundle: .module), role: .cancel) {}
        } message: {
            Text(model.actionMessage ?? "")
        }
        .confirmationDialog(
            String(localized: "Empty trash?", bundle: .module),
            isPresented: $showEmptyTrashConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Empty Trash", bundle: .module), role: .destructive) {
                Task { await model.emptyTrash() }
            }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        } message: {
            Text("Permanently deletes the trashed media files. They can't be restored afterwards.", bundle: .module)
        }
        .task { await model.runMediaCheck() }
    }

}

private extension MediaCheckResultView {
    func contentList(result: MediaCheckResult) -> some View {
        List {
            summarySection(result: result)
            if !result.missing.isEmpty { missingSection(result: result) }
            if !result.unused.isEmpty { unusedSection(result: result) }
            if result.haveTrash || !result.unused.isEmpty { trashSection(result: result) }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
    }

    func summarySection(result: MediaCheckResult) -> some View {
        Section {
            Label(
                String(localized: "\(result.missing.count) missing files", bundle: .module),
                systemImage: "exclamationmark.triangle"
            )
            .amgiStatusText(result.missing.isEmpty ? .neutral : .danger)
            .listRowBackground(palette.surfaceElevated)

            Label(
                String(localized: "\(result.unused.count) unused files", bundle: .module),
                systemImage: "archivebox"
            )
            .amgiStatusText(result.unused.isEmpty ? .neutral : .warning)
            .listRowBackground(palette.surfaceElevated)

            if !result.report.isEmpty {
                DisclosureGroup(String(localized: "Full report", bundle: .module)) {
                    Text(result.report)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .listRowBackground(palette.surfaceElevated)
            }
        } header: {
            SettingsListHeader(String(localized: "Summary", bundle: .module))
        }
    }

    func missingSection(result: MediaCheckResult) -> some View {
        Section {
            ForEach(result.missing.prefix(200), id: \.self) { file in
                Label(file, systemImage: "questionmark.circle")
                    .amgiStatusText(.danger, font: .caption)
                    .listRowBackground(palette.surfaceElevated)
            }
            if result.missing.count > 200 {
                Text("…and \(result.missing.count - 200) more", bundle: .module)
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .listRowBackground(palette.surfaceElevated)
            }
        } header: {
            SettingsListHeader(String(localized: "Missing files", bundle: .module))
        }
    }

    func unusedSection(result: MediaCheckResult) -> some View {
        Section {
            ForEach(result.unused.prefix(200), id: \.self) { file in
                Label(file, systemImage: "tray")
                    .amgiStatusText(.warning, font: .caption)
                    .listRowBackground(palette.surfaceElevated)
            }
            if result.unused.count > 200 {
                Text("…and \(result.unused.count - 200) more", bundle: .module)
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .listRowBackground(palette.surfaceElevated)
            }
        } header: {
            SettingsListHeader(String(localized: "Unused files", bundle: .module))
        }
    }

    func trashSection(result: MediaCheckResult) -> some View {
        Section {
            if !result.unused.isEmpty {
                Button {
                    Task { await model.trashUnused(filenames: result.unused) }
                } label: {
                    if model.isTrashingUnused {
                        HStack {
                            Text("Trash unused files", bundle: .module)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ProgressView()
                        }
                    } else {
                        Label(String(localized: "Trash unused files", bundle: .module), systemImage: "trash")
                    }
                }
                .disabled(model.isTrashingUnused)
                .listRowBackground(palette.surfaceElevated)
            }

            if result.haveTrash {
                Button(role: .destructive) {
                    showEmptyTrashConfirm = true
                } label: {
                    if model.isDeletingTrash {
                        HStack {
                            Text("Empty trash", bundle: .module)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ProgressView()
                        }
                    } else {
                        Label(String(localized: "Empty trash…", bundle: .module), systemImage: "trash.slash")
                    }
                }
                .disabled(model.isDeletingTrash)
                .listRowBackground(palette.surfaceElevated)

                Button {
                    Task { await model.restoreTrash() }
                } label: {
                    if model.isRestoringTrash {
                        HStack {
                            Text("Restore trash", bundle: .module)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ProgressView()
                        }
                    } else {
                        Label(String(localized: "Restore trash", bundle: .module), systemImage: "arrow.uturn.backward")
                    }
                }
                .disabled(model.isRestoringTrash)
                .listRowBackground(palette.surfaceElevated)
            }
        } header: {
            SettingsListHeader(String(localized: "Actions", bundle: .module))
        }
    }

}

// MARK: - Preview

#if DEBUG
#Preview {
    let _ = prepareDependencies {
        $0.mediaClient.checkMedia = {
            MediaCheckResult(
                missing: ["audio_こんにちは.mp3", "diagram_42.png"],
                unused: ["old_cover.jpg", "unused_clip.mp3", "stale.png"],
                missingNoteIDs: [],
                report: "2 missing, 3 unused files found.",
                haveTrash: true
            )
        }
    }
    return NavigationStack {
        MediaCheckResultView()
    }
}
#endif
