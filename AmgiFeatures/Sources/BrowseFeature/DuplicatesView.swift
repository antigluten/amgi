//
//  DuplicatesView.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 13.09.2026.
//

package import SwiftUI
import Theme
import AnkiKit

@MainActor
package struct DuplicatesView: View {
    @Environment(\.palette) private var palette

    @State private var model = DuplicatesModel()
    @State private var expanded: Set<DuplicateGroup.ID> = []

    package init() {}

    package var body: some View {
        content
            .background(palette.background)
            .navigationTitle("Duplicates")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Check for Duplicates", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await model.load() } }
            }

        case .loaded(let groups) where groups.isEmpty:
            ContentUnavailableView(
                "No Duplicates",
                systemImage: "checkmark.circle",
                description: Text("No two notes in your collection share a first field.")
            )

        case .loaded(let groups):
            groupList(groups)
        }
    }

    private func groupList(_ groups: [DuplicateGroup]) -> some View {
        List {
            Section {
                ForEach(groups) { group in
                    groupRow(group)
                }
            } header: {
                Text("\(groups.count) group\(groups.count == 1 ? "" : "s")")
            } footer: {
                Text("Notes are duplicates when their first fields match once formatting is ignored — the same rule Anki uses when it warns you while adding a note.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .listStyle(.insetGrouped)
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private func groupRow(_ group: DuplicateGroup) -> some View {
        DisclosureGroup(isExpanded: expansionBinding(group)) {
            ForEach(model.notesByGroup[group.id] ?? []) { note in
                NavigationLink {
                    NoteEditingDestinationView(note: note) {
                        Task { await model.load() }
                    }
                } label: {
                    DuplicateNoteRow(note: note)
                }
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        Task { await model.delete(note, from: group) }
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.value)
                    .amgiFont(.body)
                    .lineLimit(1)
                Text("\(group.noteIDs.count) notes")
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func expansionBinding(_ group: DuplicateGroup) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(group.id) },
            set: { isExpanded in
                if isExpanded {
                    expanded.insert(group.id)
                    Task { await model.loadNotes(for: group) }
                } else {
                    expanded.remove(group.id)
                }
            }
        )
    }
}

private struct DuplicateNoteRow: View {
    @Environment(\.palette) private var palette

    let note: NoteRecord

    private var remainder: String {
        note.flds
            .split(separator: "\u{1f}", omittingEmptySubsequences: false)
            .dropFirst()
            .joined(separator: " · ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(remainder.isEmpty ? "No other fields" : remainder)
                .amgiFont(.body)
                .foregroundStyle(remainder.isEmpty ? palette.textSecondary : palette.textPrimary)
                .lineLimit(2)
            if !note.tags.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(note.tags.trimmingCharacters(in: .whitespaces))
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}
