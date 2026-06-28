import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Tag-management I/O for `TagsView`. Owns the `tagClient` dependency and
/// the engine-coupled state (the tag list, load/apply/delete flags, error
/// alert) so the view carries no `@Dependency`. Target note ids are passed
/// per call; the view keeps its selection/sheet/dialog UI state and resets
/// it after each action.
@Observable
@MainActor
final class TagsModel {
    var allTags: [String] = []
    var isLoading = true
    var errorMessage: String?
    var showError = false
    var isApplying = false
    var isDeleting = false

    @ObservationIgnored @Dependency(\.tagClient) private var tagClient

    func loadTags() async {
        do {
            allTags = try tagClient.getAllTags().sorted()
            isLoading = false
        } catch {
            errorMessage = "Failed to load tags: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }

    /// Adds `name` collection-wide when `targetNoteIDs` is empty, otherwise to
    /// the given notes. Returns `true` on success so the view can clear its
    /// draft + dismiss the add sheet.
    func createTag(name: String, targetNoteIDs: [NoteID]) async -> Bool {
        do {
            if targetNoteIDs.isEmpty {
                try tagClient.addTag(name)
            } else {
                try tagClient.addTagToNotes(name, targetNoteIDs)
            }
            await loadTags()
            return true
        } catch {
            errorMessage = "Failed to create tag: \(error.localizedDescription)"
            showError = true
            return false
        }
    }

    func applyTag(_ tag: String, targetNoteIDs: [NoteID]) async {
        isApplying = true
        defer { isApplying = false }
        do {
            try tagClient.addTagToNotes(tag, targetNoteIDs)
        } catch {
            errorMessage = "Failed to apply tag: \(error.localizedDescription)"
            showError = true
        }
    }

    func removeTagFromNotes(_ tag: String, targetNoteIDs: [NoteID]) async {
        isApplying = true
        defer { isApplying = false }
        do {
            try tagClient.removeTagFromNotes(tag, targetNoteIDs)
        } catch {
            errorMessage = "Failed to remove tag: \(error.localizedDescription)"
            showError = true
        }
    }

    func deleteTag(_ tag: String) async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try tagClient.removeTag(tag)
            await loadTags()
        } catch {
            errorMessage = "Failed to delete tag: \(error.localizedDescription)"
            showError = true
        }
    }

    /// Returns `true` when the rename actually ran (non-empty, changed name).
    func renameTag(from oldName: String, to newName: String) async -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldName else { return false }
        do {
            try tagClient.renameTag(oldName, trimmed)
            await loadTags()
            return true
        } catch {
            errorMessage = "Failed to rename tag: \(error.localizedDescription)"
            showError = true
            return false
        }
    }
}
