//
//  CardActionsLiveTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 31.08.2026.
//

import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

/// Live check for `cardIDsOfNote` / `suspendCards` / `buryCards` against the
/// real Rust backend. Their method IDs are derived by counting rpcs in the
/// .proto service blocks, and a miscount dispatches to a *different* method
/// rather than failing — only a round-trip against the backend catches that.
@Suite struct CardActionsLiveTests {
    @Test func cardsOfNote_then_suspend_then_bury() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("card-actions-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let backend = try AnkiBackend()
        try backend.openCollection(
            collectionPath: dir.appendingPathComponent("collection.anki2").path,
            mediaFolderPath: dir.appendingPathComponent("media").path,
            mediaDbPath: dir.appendingPathComponent("media.db").path
        )
        defer { try? backend.closeCollection() }

        // "Basic (and reversed card)" generates two cards, so cardIDsOfNote
        // returning one id would be indistinguishable from a partial result.
        let names = try backend.invoke(.notetypeNames)
        let reversed = try #require(names.first { $0.name == "Basic (and reversed card)" })
        var template = try backend.invoke(.newNote(notetypeId: reversed.id))
        try #require(template.fields.count >= 2)
        template.fields[0] = "front"
        template.fields[1] = "back"
        try backend.invoke(.addNote(template: template, deckId: DeckID(1)))

        let queued: QueuedCardsResult = try backend.invoke(.getQueuedCards(fetchLimit: 1))
        let noteId = try #require(queued.cards.first?.card.nid)

        let cardIds = try backend.invoke(.cardIDsOfNote(id: noteId))
        #expect(cardIds.count == 2)
        for id in cardIds {
            #expect(try backend.invoke(.getCard(id: id)).nid == noteId)
        }

        // CardQueue: 0 = new, -1 = suspended, -3 = user-buried.
        #expect(try backend.invoke(.getCard(id: cardIds[0])).queue == 0)

        try backend.invoke(.suspendCards(cardIds: [cardIds[0]]))
        #expect(try backend.invoke(.getCard(id: cardIds[0])).queue == -1)
        #expect(try backend.invoke(.getCard(id: cardIds[1])).queue == 0)

        try backend.invoke(.buryCards(cardIds: [cardIds[1]]))
        #expect(try backend.invoke(.getCard(id: cardIds[1])).queue == -3)
    }

    /// The behaviour the whole re-queue design rests on (see
    /// `Documentation/adr/0001-live-session-total.md`): a card that is taken out
    /// of study is simply absent from the *next* gathering, the counts are
    /// derived from that same gathering so they drop with it, and the collection
    /// undo stack is the only way back — nothing in the wrapped surface
    /// un-suspends one card.
    @Test func suspended_cards_leave_the_next_gather_and_the_counts_drop_with_them() throws {
        try withScratchCollection("card-actions-requeue") { backend, _ in
            let names = try backend.invoke(.notetypeNames)
            let reversed = try #require(names.first { $0.name == "Basic (and reversed card)" })
            var template = try backend.invoke(.newNote(notetypeId: reversed.id))
            try #require(template.fields.count >= 2)
            template.fields[0] = "front"
            template.fields[1] = "back"
            try backend.invoke(.addNote(template: template, deckId: DeckID(1)))

            let start = try backend.invoke(.getQueuedCards(fetchLimit: 200))
            let noteId = try #require(start.cards.first?.card.nid)
            let cardIds = try backend.invoke(.cardIDsOfNote(id: noteId))
            #expect(start.cards.count == 2)
            #expect(start.newCount == 2)
            #expect(try backend.invoke(.deckCounts(for: DeckID(1)))?.newCount == 2)

            // Card-scope: the sibling of the same note stays queued.
            try backend.invoke(.suspendCards(cardIds: [cardIds[0]]))
            let afterCard = try backend.invoke(.getQueuedCards(fetchLimit: 200))
            #expect(Set(afterCard.cards.map { $0.card.id }) == Set([cardIds[1]]))
            #expect(afterCard.newCount == 1)
            #expect(try backend.invoke(.deckCounts(for: DeckID(1)))?.newCount == 1)

            // Note-scope, as `CardContextMenuModel.suspendNote` runs it: every
            // remaining card of the note goes in one step.
            let siblings = cardIds.filter { $0 != cardIds[0] }
            try backend.invoke(.suspendCards(cardIds: siblings))
            let drained = try backend.invoke(.getQueuedCards(fetchLimit: 200))
            #expect(drained.cards.isEmpty)
            #expect(drained.newCount == 0)
            #expect(try backend.invoke(.deckCounts(for: DeckID(1)))?.newCount == 0)

            // Undo is what recovery looks like today, and the card returns where
            // it would have been — which is why suspending is not a grade.
            #expect(try backend.invoke(.hasUndoableAction))
            try backend.invoke(.undoLastAction)
            let restored = try backend.invoke(.getQueuedCards(fetchLimit: 200))
            #expect(Set(restored.cards.map { $0.card.id }) == Set(siblings))
        }
    }
}
