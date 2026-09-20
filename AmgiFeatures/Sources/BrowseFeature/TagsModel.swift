//
//  TagsModel.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 27.06.2026.
//

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
    /// Non-nil drives the error alert; there is no separate `showError`
    /// flag to keep in sync with it.
    var errorMessage: String?
    var isApplying = false
    var isDeleting = false
    var lastCleanupCount: Int?

    @ObservationIgnored @Dependency(\.tagClient) private var tagClient

    func loadTags() async {
        do {
            allTags = try await tagClient.getAllTags().sorted()
            isLoading = false
        } catch {
            errorMessage = "Failed to load tags: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Adds `name` collection-wide when `targetNoteIDs` is empty, otherwise to
    /// the given notes. Returns `true` on success so the view can clear its
    /// draft + dismiss the add sheet.
    func createTag(name: String, targetNoteIDs: [NoteID]) async -> Bool {
        do {
            if targetNoteIDs.isEmpty {
                try await tagClient.addTag(name)
            } else {
                try await tagClient.addTagToNotes(name, targetNoteIDs)
            }
            await loadTags()
            return true
        } catch {
            errorMessage = "Failed to create tag: \(error.localizedDescription)"
            return false
        }
    }

    func applyTag(_ tag: String, targetNoteIDs: [NoteID]) async {
        isApplying = true
        defer { isApplying = false }
        do {
            try await tagClient.addTagToNotes(tag, targetNoteIDs)
        } catch {
            errorMessage = "Failed to apply tag: \(error.localizedDescription)"
        }
    }

    func removeTagFromNotes(_ tag: String, targetNoteIDs: [NoteID]) async {
        isApplying = true
        defer { isApplying = false }
        do {
            try await tagClient.removeTagFromNotes(tag, targetNoteIDs)
        } catch {
            errorMessage = "Failed to remove tag: \(error.localizedDescription)"
        }
    }

    func deleteTag(_ tag: String) async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await tagClient.removeTag(tag)
            await loadTags()
        } catch {
            errorMessage = "Failed to delete tag: \(error.localizedDescription)"
        }
    }

    func clearUnusedTags() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            lastCleanupCount = try await tagClient.clearUnusedTags()
            await loadTags()
        } catch {
            errorMessage = "Failed to clear unused tags: \(error.localizedDescription)"
        }
    }

    /// Returns `true` when the rename actually ran (non-empty, changed name).
    func renameTag(from oldName: String, to newName: String) async -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldName else { return false }
        do {
            try await tagClient.renameTag(oldName, trimmed)
            await loadTags()
            return true
        } catch {
            errorMessage = "Failed to rename tag: \(error.localizedDescription)"
            return false
        }
    }
}
