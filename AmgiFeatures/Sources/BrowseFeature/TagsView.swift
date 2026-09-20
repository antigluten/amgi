//
//  TagsView.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 28.04.2026.
//

package import SwiftUI
import Theme
import AnkiClients
package import AnkiKit
import Dependencies
import SwiftUINavigation

/// View for managing tags in the collection.
/// When `targetNoteIDs` is non-empty the view acts as a "apply / remove tag"
/// picker for the selected notes.  When empty it is a collection-level tag
/// manager.
@MainActor
package struct TagsView: View {
    let targetNoteIDs: [NoteID]
    /// Controls behaviour when `targetNoteIDs` is non-empty.
    /// `.addToNotes` — tapping a tag immediately adds it to all selected notes.
    /// `.removeFromNotes` — tapping a tag immediately removes it from all selected notes.
    /// `.manage` (default) — tapping a tag shows a confirmation dialog.
    let noteMode: NoteMode

    package enum NoteMode { case manage, addToNotes, removeFromNotes }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var model = TagsModel()
    @State private var destination: TagsDestination?

    package init(targetNoteIDs: [NoteID] = [], noteMode: NoteMode = .manage) {
        self.targetNoteIDs = targetNoteIDs
        self.noteMode = noteMode
    }

    // Whether this view is in "apply tags to notes" mode
    private var isNoteMode: Bool { !targetNoteIDs.isEmpty }

    package var body: some View {
        presenting(chrome)
            .task {
                await loadTags()
            }
    }

    private var chrome: some View {
        stateContent
            .background(palette.background)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Tag", systemImage: "plus") { destination = .addTag("") }
                }
                if !isNoteMode {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Clear Unused Tags", systemImage: "sparkles") {
                                Task { await model.clearUnusedTags() }
                            }
                            .disabled(model.isDeleting)
                        } label: {
                            Label("More", systemImage: "ellipsis")
                        }
                    }
                }
            }
            .alert(
                "Unused Tags Cleared",
                isPresented: Binding(
                    get: { model.lastCleanupCount != nil },
                    set: { if !$0 { model.lastCleanupCount = nil } }
                ),
                presenting: model.lastCleanupCount
            ) { _ in
                Button("OK") { model.lastCleanupCount = nil }
            } message: { count in
                Text(count == 0
                    ? "Every tag in your collection is still in use."
                    : "Removed \(count) tag\(count == 1 ? "" : "s") that no note was using.")
            }
    }

    @ViewBuilder
    private var stateContent: some View {
        if model.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.allTags.isEmpty {
            ContentUnavailableView(
                "No Tags",
                systemImage: "tag.slash",
                description: Text(isNoteMode
                    ? "These notes don't have any tags."
                    : "Your collection has no tags yet.")
            )
        } else {
            tagListContent
        }
    }

    // MARK: - Computed

    private var navigationTitle: String {
        switch noteMode {
        case .addToNotes: return "Add Tag"
        case .removeFromNotes: return "Remove Tag"
        case .manage: return isNoteMode ? "Tags on Notes" : "Tags"
        }
    }

    // MARK: - Extracted Sub-Views

    private var tagListContent: some View {
        List {
            if isNoteMode {
                Section {
                    Label("Tap a tag to act on \(targetNoteIDs.count) selected note\(targetNoteIDs.count == 1 ? "" : "s")", systemImage: "doc.text")
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            }

            Section(isNoteMode ? "Available Tags" : "All Tags") {
                ForEach(model.allTags, id: \.self) { tag in
                    tagRow(tag)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .listStyle(.insetGrouped)
    }

    /// Every modal the screen can show, read off the single `destination`.
    /// Lifted out of `body` so that stays a composition rather than an alert stack.
    private func presenting(_ content: some View) -> some View {
        content
            .sheet(isPresented: Binding($destination.addTag)) {
                addTagSheet
            }
            .confirmationDialog(
                "Delete Tag?",
                isPresented: Binding($destination.deleteTag),
                titleVisibility: .visible,
                presenting: pendingDeleteTag
            ) { tag in
                Button("Delete", role: .destructive) {
                    Task { await deleteTag(tag) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { tag in
                Text("Delete \"\(tag)\"? This will remove it from all notes.")
            }
            .alert(
                "Rename Tag",
                isPresented: Binding($destination.renameTag),
                presenting: pendingRename
            ) { rename in
                TextField("New name", text: renameNameBinding)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    Task { await renameTagAction(from: rename.original, to: renameNameBinding.wrappedValue) }
                }
            } message: { rename in
                Text("Enter a new name for \"\(rename.original)\". It will be updated on all notes that use it.")
            }
            .alert("Couldn't update tags", isPresented: Binding($model.errorMessage)) {
                Button("OK") {}
            } message: {
                Text(model.errorMessage ?? "An unknown error occurred.")
            }
            .confirmationDialog(
                pendingNoteActionTag ?? "",
                isPresented: Binding($destination.noteAction),
                titleVisibility: .visible,
                presenting: pendingNoteActionTag
            ) { tag in
                Button("Apply to \(targetNoteIDs.count) note\(targetNoteIDs.count == 1 ? "" : "s")") {
                    Task { await applyTag(tag) }
                }
                Button("Remove from \(targetNoteIDs.count) note\(targetNoteIDs.count == 1 ? "" : "s")", role: .destructive) {
                    Task { await removeTagFromSelectedNotes(tag) }
                }
                Button("Cancel", role: .cancel) {}
            }
    }

    private var pendingDeleteTag: String? {
        if case .deleteTag(let tag) = destination { return tag }
        return nil
    }

    private var pendingRename: TagRename? {
        if case .renameTag(let rename) = destination { return rename }
        return nil
    }

    private var pendingNoteActionTag: String? {
        if case .noteAction(let tag) = destination { return tag }
        return nil
    }

    /// The rename alert's text field edits the draft in place inside
    /// `destination`, so there's no second copy of the name to keep in sync.
    private var renameNameBinding: Binding<String> {
        Binding(
            get: { pendingRename?.newName ?? "" },
            set: { newValue in
                guard var rename = pendingRename else { return }
                rename.newName = newValue
                destination = .renameTag(rename)
            }
        )
    }

    private var newTagNameBinding: Binding<String> {
        Binding(
            get: { if case .addTag(let name) = destination { return name }; return "" },
            set: { destination = .addTag($0) }
        )
    }

    private var addTagSheet: some View {
        NavigationStack {
            Form {
                if isNoteMode {
                    Section("Selected Notes") {
                        Text("The new tag will be applied to \(targetNoteIDs.count) selected note\(targetNoteIDs.count == 1 ? "" : "s").")
                            .amgiFont(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                Section("Tag Name") {
                    TextField("e.g. anatomy::heart", text: newTagNameBinding)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Button(isNoteMode ? "Create & Apply" : "Create Tag") {
                        Task { await createTag() }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { destination = nil }
                }
            }
        }
    }

    // MARK: - Actions
}

private extension TagsView {
    @ViewBuilder
    func tagRow(_ tag: String) -> some View {
        Button {
            if isNoteMode {
                switch noteMode {
                case .addToNotes:
                    Task { await applyTag(tag) }
                case .removeFromNotes:
                    Task { await removeTagFromSelectedNotes(tag) }
                case .manage:
                    destination = .noteAction(tag)
                }
            }
        } label: {
            HStack {
                Label(tag, systemImage: "tag.fill")
                    .foregroundStyle(palette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if model.isApplying && pendingNoteActionTag == tag {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textTertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressScale)
        .swipeActions(edge: .trailing) {
            if isNoteMode {
                Button {
                    Task { await removeTagFromSelectedNotes(tag) }
                } label: {
                    Label("Remove", systemImage: "tag.slash")
                }
                .tint(palette.warning)

                Button {
                    Task { await applyTag(tag) }
                } label: {
                    Label("Apply", systemImage: "tag")
                }
                .tint(palette.accent)
            } else {
                Button(role: .destructive) {
                    destination = .deleteTag(tag)
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    destination = .renameTag(TagRename(original: tag))
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(palette.accent)
            }
        }
    }

    // Thin delegators to the model: do the engine work, then reset the
    // view's selection/sheet/dialog state.

    func loadTags() async {
        await model.loadTags()
    }

    func createTag() async {
        let name = newTagNameBinding.wrappedValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if await model.createTag(name: name, targetNoteIDs: targetNoteIDs) {
            destination = nil
        }
    }

    func applyTag(_ tag: String) async {
        await model.applyTag(tag, targetNoteIDs: targetNoteIDs)
        destination = nil
    }

    func removeTagFromSelectedNotes(_ tag: String) async {
        await model.removeTagFromNotes(tag, targetNoteIDs: targetNoteIDs)
        destination = nil
    }

    func deleteTag(_ tag: String) async {
        await model.deleteTag(tag)
        destination = nil
    }

    func renameTagAction(from oldName: String, to newName: String) async {
        _ = await model.renameTag(from: oldName, to: newName)
        destination = nil
    }
}

#if DEBUG

#Preview {
    let _ = prepareDependencies {
        $0.tagClient.getAllTags = { ["anatomy", "anatomy::heart", "grammar", "n5", "vocab"] }
    }
    return NavigationStack {
        TagsView()
    }
    .environment(\.palette, .vividDark)
    .preferredColorScheme(.dark)
}

#Preview("Note mode") {
    let _ = prepareDependencies {
        $0.tagClient.getAllTags = { ["anatomy", "grammar", "n5", "vocab"] }
    }
    return NavigationStack {
        TagsView(targetNoteIDs: [NoteID(1), NoteID(2), NoteID(3)])
    }
    .environment(\.palette, .vividDark)
    .preferredColorScheme(.dark)
}
#endif
