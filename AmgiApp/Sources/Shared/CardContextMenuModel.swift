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

    func suspend(_ cardId: CardID) -> Bool? {
        run("Suspend failed") { try cardClient.suspend(cardId); return true }
    }

    func bury(_ cardId: CardID) -> Bool? {
        run("Bury failed") { try cardClient.bury(cardId); return true }
    }

    func resetToNew(_ cardId: CardID) -> Bool? {
        run("Forget failed") { try cardClient.resetToNew(cardId); return true }
    }

    func deleteNote(_ noteId: NoteID) -> Bool? {
        run("Delete note failed") { try noteClient.delete(noteId); return true }
    }

    func toggleMarked(_ noteId: NoteID) -> Bool? {
        run("Mark note failed") {
            if isMarkedNote {
                try tagClient.removeTagFromNotes(markedTag, [noteId])
            } else {
                try tagClient.addTagToNotes(markedTag, [noteId])
            }
            isMarkedNote.toggle()
            return false
        }
    }

    func suspendNote(_ noteId: NoteID) -> Bool? {
        noteAction(noteId, "Suspend note failed") { try cardClient.suspend($0) }
    }

    func buryNote(_ noteId: NoteID) -> Bool? {
        noteAction(noteId, "Bury note failed") { try cardClient.bury($0) }
    }

    func flag(_ cardId: CardID, _ value: UInt32) -> Bool? {
        run("Flag failed") {
            try cardClient.flag(cardId, value)
            currentFlag = value
            return false
        }
    }

    func undo(_ cardId: CardID) async -> Bool? {
        guard !isUndoing, canUndo else { return nil }
        isUndoing = true
        defer { isUndoing = false }
        do {
            try cardClient.undoLast()
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
        currentFlag = (try? cardClient.getCardFlags(cardId)) ?? 0
        await refreshUndoAvailability()
    }

    // MARK: - Helpers

    private func run(_ prefix: String, _ body: () throws -> Bool) -> Bool? {
        do {
            return try body()
        } catch {
            setError("\(prefix): \(error.localizedDescription)")
            return nil
        }
    }

    private func noteAction(_ noteId: NoteID, _ prefix: String, _ action: (CardID) throws -> Void) -> Bool? {
        run(prefix) {
            let cards = try cardClient.fetchByNote(noteId)
            for card in cards {
                try action(card.id)
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
            let note = try noteClient.fetch(noteId)
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
        canUndo = (try? cardClient.hasUndoableAction()) ?? false
    }

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

private let markedTag = "marked"
