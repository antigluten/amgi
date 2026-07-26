import SwiftUI
import AmgiTheme
import AnkiClients
import AnkiKit
import Dependencies

/// View for managing tags in the collection.
/// When `targetNoteIDs` is non-empty the view acts as a "apply / remove tag"
/// picker for the selected notes.  When empty it is a collection-level tag
/// manager.
@MainActor
struct TagsView: View {
    let targetNoteIDs: [NoteID]
    /// Controls behaviour when `targetNoteIDs` is non-empty.
    /// `.addToNotes` — tapping a tag immediately adds it to all selected notes.
    /// `.removeFromNotes` — tapping a tag immediately removes it from all selected notes.
    /// `.manage` (default) — tapping a tag shows a confirmation dialog.
    let noteMode: NoteMode

    enum NoteMode { case manage, addToNotes, removeFromNotes }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var model = TagsModel()
    @State private var showAddTag = false
    @State private var newTagName: String = ""
    @State private var selectedTag: String?
    @State private var showDeleteConfirm = false
    @State private var tagActionTag: String?
    @State private var showRenameTag = false
    @State private var tagToRename: String?
    @State private var renameTagName = ""

    init(targetNoteIDs: [NoteID] = [], noteMode: NoteMode = .manage) {
        self.targetNoteIDs = targetNoteIDs
        self.noteMode = noteMode
    }

    // Whether this view is in "apply tags to notes" mode
    private var isNoteMode: Bool { !targetNoteIDs.isEmpty }

    var body: some View {
        VStack {
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
        .background(palette.background)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Tag", systemImage: "plus") { showAddTag = true }
            }
        }
        .sheet(isPresented: $showAddTag) {
            addTagSheet
        }
        .alert("Delete Tag?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let tag = selectedTag {
                    Task { await deleteTag(tag) }
                }
            }
        } message: {
            if let tag = selectedTag {
                Text("Delete \"\(tag)\"? This will remove it from all notes.")
            }
        }
        .alert("Rename Tag", isPresented: $showRenameTag) {
            TextField("New name", text: $renameTagName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) { tagToRename = nil }
            Button("Rename") {
                if let old = tagToRename {
                    Task { await renameTagAction(from: old, to: renameTagName) }
                }
            }
        } message: {
            if let tag = tagToRename {
                Text("Enter a new name for \"\(tag)\". It will be updated on all notes that use it.")
            }
        }
        .alert("Error", isPresented: $model.showError) {
            Button("OK") { }
        } message: {
            Text(model.errorMessage ?? "An unknown error occurred.")
        }
        .confirmationDialog(
            tagActionTag ?? "",
            isPresented: Binding(
                get: { tagActionTag != nil && isNoteMode && noteMode == .manage },
                set: { if !$0 { tagActionTag = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let tag = tagActionTag {
                Button("Apply to \(targetNoteIDs.count) note\(targetNoteIDs.count == 1 ? "" : "s")") {
                    Task { await applyTag(tag) }
                }
                Button("Remove from \(targetNoteIDs.count) note\(targetNoteIDs.count == 1 ? "" : "s")", role: .destructive) {
                    Task { await removeTagFromSelectedNotes(tag) }
                }
                Button("Cancel", role: .cancel) { tagActionTag = nil }
            }
        }
        .task {
            await loadTags()
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
                    TextField("e.g. anatomy::heart", text: $newTagName)
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showAddTag = false }
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
                    tagActionTag = tag
                }
            } else {
                selectedTag = tag
            }
        } label: {
            HStack {
                Label(tag, systemImage: "tag.fill")
                    .foregroundStyle(palette.accent)
                Spacer()
                if model.isApplying && tagActionTag == tag {
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
        .buttonStyle(.plain)
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
                    selectedTag = tag
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    tagToRename = tag
                    renameTagName = tag
                    showRenameTag = true
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
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if await model.createTag(name: name, targetNoteIDs: targetNoteIDs) {
            newTagName = ""
            showAddTag = false
        }
    }

    func applyTag(_ tag: String) async {
        await model.applyTag(tag, targetNoteIDs: targetNoteIDs)
        tagActionTag = nil
    }

    func removeTagFromSelectedNotes(_ tag: String) async {
        await model.removeTagFromNotes(tag, targetNoteIDs: targetNoteIDs)
        tagActionTag = nil
    }

    func deleteTag(_ tag: String) async {
        await model.deleteTag(tag)
        selectedTag = nil
    }

    func renameTagAction(from oldName: String, to newName: String) async {
        _ = await model.renameTag(from: oldName, to: newName)
        tagToRename = nil
    }
}

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
