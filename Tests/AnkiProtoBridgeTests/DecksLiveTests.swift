//
//  DecksLiveTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

@Suite struct DecksLiveTests {
    @Test func deckLifecycle_create_rename_remove() throws {
        try withScratchCollection("decks") { backend, _ in
            let initial = try backend.invoke(.deckNames)
            #expect(initial.contains { $0.id == DeckID(1) })

            let template = try backend.invoke(.newDeck)
            let created = try backend.invoke(.addDeck(template: template, name: "Probe"))
            #expect(created.id != DeckID(1))
            #expect(created.changes.deck, "addDeck must report the deck facet dirty")

            let afterAdd = try backend.invoke(.deckNames)
            #expect(afterAdd.count == initial.count + 1)
            #expect(afterAdd.contains { $0.id == created.id && $0.name == "Probe" })

            let renamed = try backend.invoke(.renameDeck(deckId: created.id, newName: "Probed"))
            #expect(renamed.deck)
            #expect(try backend.invoke(.deckNames).contains { $0.id == created.id && $0.name == "Probed" })

            let removed = try backend.invoke(.removeDecks(deckIds: [created.id]))
            #expect(removed.deck)
            #expect(try backend.invoke(.deckNames).count == initial.count)
        }
    }

    @Test func currentDeck_roundTrips() throws {
        try withScratchCollection("decks-current") { backend, _ in
            let template = try backend.invoke(.newDeck)
            let created = try backend.invoke(.addDeck(template: template, name: "Current"))

            try backend.invoke(.setCurrentDeck(deckId: created.id))
            #expect(try backend.invoke(.getCurrentDeck).id == created.id)

            try backend.invoke(.setCurrentDeck(deckId: DeckID(1)))
            #expect(try backend.invoke(.getCurrentDeck).id == DeckID(1))
        }
    }

    @Test func deckTree_andCounts_seeTheAddedCard() throws {
        try withScratchCollection("decks-tree") { backend, _ in
            let skeleton = try backend.invoke(.deckTree(at: Date(timeIntervalSince1970: 0)))
            #expect(skeleton.find(DeckID(1)) != nil, "Default deck must be in the tree")

            let names = try backend.invoke(.notetypeNames)
            let basic = try #require(names.first { $0.name == "Basic" })
            var note = try backend.invoke(.newNote(notetypeId: basic.id))
            note.fields[0] = "front"
            note.fields[1] = "back"
            try backend.invoke(.addNote(template: note, deckId: DeckID(1)))

            let tree = try backend.invoke(.deckTree(at: Date()))
            let root = try #require(tree.find(DeckID(1)))
            #expect(root.counts.newCount == 1)

            let counts = try #require(try backend.invoke(.deckCounts(for: DeckID(1))))
            #expect(counts.newCount == 1)
            #expect(counts.total == 1)
        }
    }
}
