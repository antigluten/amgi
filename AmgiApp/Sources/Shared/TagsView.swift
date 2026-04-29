import SwiftUI
import AmgiTheme
import AnkiClients
import Dependencies

/// View for managing tags in the collection.
/// When `targetNoteIDs` is non-empty the view acts as a "apply / remove tag"
/// picker for the selected notes.  When empty it is a collection-level tag
/// manager.
@MainActor
struct TagsView: View {
    @Dependency(\.tagClient) var tagClient
    let targetNoteIDs: [Int64]
    /// Controls behaviour when `targetNoteIDs` is non-empty.
    /// `.addToNotes` — tapping a tag immediately adds it to all selected notes.
    /// `.removeFromNotes` — tapping a tag immediately removes it from all selected notes.
    /// `.manage` (default) — tapping a tag shows a confirmation dialog.
    let noteMode: NoteMode

    enum NoteMode { case manage, addToNotes, removeFromNotes }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var allTags: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showAddTag = false
    @State private var newTagName: String = ""
    @State private var selectedTag: String?
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var tagActionTag: String?
    @State private var isApplying = false
    @State private var showRenameTag = false
    @State private var tagToRename: String?
    @State private var renameTagName = ""

    init(targetNoteIDs: [Int64] = [], noteMode: NoteMode = .manage) {
        self.targetNoteIDs = targetNoteIDs
        self.noteMode = noteMode
    }

    // Whether this view is in "apply tags to notes" mode
    private var isNoteMode: Bool { !targetNoteIDs.isEmpty }

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if allTags.isEmpty {
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddTag = true }) {
                        Image(systemName: "plus")
                    }
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
                    Text("Delete \"\(tag)\"? This will remove it from all notes.")
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
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
                ForEach(allTags.sorted(), id: \.self) { tag in
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

    // MARK: - Row

    @ViewBuilder
    private func tagRow(_ tag: String) -> some View {
        HStack {
            Label(tag, systemImage: "tag.fill")
                .foregroundStyle(palette.accent)
            Spacer()
            if isApplying && tagActionTag == tag {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "chevron.right")
                    .font(AmgiFont.caption.font)
                    .foregroundStyle(palette.textTertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
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
        }
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

    // MARK: - Actions

    private func loadTags() async {
        do {
            allTags = try tagClient.getAllTags()
            isLoading = false
        } catch {
            errorMessage = "Failed to load tags: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }

    private func createTag() async {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        do {
            if isNoteMode {
                try tagClient.addTagToNotes(name, targetNoteIDs)
            } else {
                try tagClient.addTag(name)
            }
            newTagName = ""
            showAddTag = false
            await loadTags()
        } catch {
            errorMessage = "Failed to create tag: \(error.localizedDescription)"
            showError = true
        }
    }

    private func applyTag(_ tag: String) async {
        isApplying = true
        defer { isApplying = false; tagActionTag = nil }
        do {
            try tagClient.addTagToNotes(tag, targetNoteIDs)
        } catch {
            errorMessage = "Failed to apply tag: \(error.localizedDescription)"
            showError = true
        }
    }

    private func removeTagFromSelectedNotes(_ tag: String) async {
        isApplying = true
        defer { isApplying = false; tagActionTag = nil }
        do {
            try tagClient.removeTagFromNotes(tag, targetNoteIDs)
        } catch {
            errorMessage = "Failed to remove tag: \(error.localizedDescription)"
            showError = true
        }
    }

    private func deleteTag(_ tag: String) async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try tagClient.removeTag(tag)
            selectedTag = nil
            await loadTags()
        } catch {
            errorMessage = "Failed to delete tag: \(error.localizedDescription)"
            showError = true
        }
    }

    private func renameTagAction(from oldName: String, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldName else {
            tagToRename = nil
            return
        }
        do {
            try tagClient.renameTag(oldName, trimmed)
            tagToRename = nil
            await loadTags()
        } catch {
            errorMessage = "Failed to rename tag: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    TagsView()
        .environment(\.palette, .vividDark)
        .preferredColorScheme(.dark)
}

#Preview("Note mode") {
    TagsView(targetNoteIDs: [1, 2, 3])
        .environment(\.palette, .vividDark)
        .preferredColorScheme(.dark)
}
