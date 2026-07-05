import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Card-operation I/O for `CardContextMenu`. Owns the card/note/tag clients
/// and the loaded display state (marked, current flag, undo availability)
/// plus the error-alert state so the menu carries no `@Dependency`.
///
/// `cardId`/`noteId` are **not** captured — the menu is a reused leaf whose
/// ids vary per use, so every action takes them as parameters and returns
/// `shouldAdvance` (`nil` on failure, with the error surfaced on the model);
/// the view forwards `onSuccess`/`onActionSuccess`.
@Observable
@MainActor
final class CardContextMenuModel {
    var isMarkedNote = false
    var currentFlag: UInt32 = 0
    var canUndo = false
    var isUndoing = false
    var errorMessage: String?
    var showError = false

    @ObservationIgnored @Dependency(\.cardClient) private var cardClient
    @ObservationIgnored @Dependency(\.noteClient) private var noteClient
    @ObservationIgnored @Dependency(\.tagClient) private var tagClient

    // MARK: - Actions (return shouldAdvance on success, nil on failure)

    func suspend(_ cardId: CardID) async -> Bool? {
        await run("Suspend failed") { try await cardClient.suspend(cardId); return true }
    }

    func bury(_ cardId: CardID) async -> Bool? {
        await run("Bury failed") { try await cardClient.bury(cardId); return true }
    }

    func resetToNew(_ cardId: CardID) async -> Bool? {
        await run("Forget failed") { try await cardClient.resetToNew(cardId); return true }
    }

    func deleteNote(_ noteId: NoteID) async -> Bool? {
        await run("Delete note failed") { try await noteClient.delete(noteId); return true }
    }

    func toggleMarked(_ noteId: NoteID) async -> Bool? {
        await run("Mark note failed") {
            if isMarkedNote {
                try await tagClient.removeTagFromNotes(markedTag, [noteId])
            } else {
                try await tagClient.addTagToNotes(markedTag, [noteId])
            }
            isMarkedNote.toggle()
            return false
        }
    }

    func suspendNote(_ noteId: NoteID) async -> Bool? {
        await noteAction(noteId, "Suspend note failed") { try await cardClient.suspend($0) }
    }

    func buryNote(_ noteId: NoteID) async -> Bool? {
        await noteAction(noteId, "Bury note failed") { try await cardClient.bury($0) }
    }

    func flag(_ cardId: CardID, _ value: UInt32) async -> Bool? {
        await run("Flag failed") {
            try await cardClient.flag(cardId, value)
            currentFlag = value
            return false
        }
    }

    func undo(_ cardId: CardID) async -> Bool? {
        guard !isUndoing, canUndo else { return nil }
        isUndoing = true
        defer { isUndoing = false }
        do {
            try await cardClient.undoLast()
            return true
        } catch {
            setError("Undo failed: \(error.localizedDescription)")
            await refreshUndoAvailability()
            return nil
        }
    }

    // MARK: - Load

    func load(cardId: CardID, noteId: NoteID?) async {
        await loadMarkedState(noteId)
        currentFlag = (try? await cardClient.getCardFlags(cardId)) ?? 0
        await refreshUndoAvailability()
    }

    // MARK: - Helpers

    private func run(_ prefix: String, _ body: () async throws -> Bool) async -> Bool? {
        do {
            return try await body()
        } catch {
            setError("\(prefix): \(error.localizedDescription)")
            return nil
        }
    }

    private func noteAction(_ noteId: NoteID, _ prefix: String, _ action: (CardID) async throws -> Void) async -> Bool? {
        await run(prefix) {
            let cards = try await cardClient.fetchByNote(noteId)
            for card in cards {
                try await action(card.id)
            }
            return true
        }
    }

    private func loadMarkedState(_ noteId: NoteID?) async {
        guard let noteId else {
            isMarkedNote = false
            return
        }
        do {
            let note = try await noteClient.fetch(noteId)
            isMarkedNote = note.map {
                $0.tags
                    .split(separator: " ")
                    .contains { $0.caseInsensitiveCompare(markedTag) == .orderedSame }
            } ?? false
        } catch {
            isMarkedNote = false
        }
    }

    private func refreshUndoAvailability() async {
        canUndo = (try? await cardClient.hasUndoableAction()) ?? false
    }

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

private let markedTag = "marked"
