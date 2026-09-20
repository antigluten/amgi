//
//  StatsLiveTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

@Suite struct StatsLiveTests {
    @Test func graphs_countsTheCardsThatExist() throws {
        try withScratchCollection("stats") { backend, _ in
            let empty = try backend.invoke(.graphs(search: "deck:*", days: 31))
            #expect(empty.cardCounts.includingInactive.newCards == 0)

            let names = try backend.invoke(.notetypeNames)
            let reversed = try #require(names.first { $0.name == "Basic (and reversed card)" })
            var note = try backend.invoke(.newNote(notetypeId: reversed.id))
            note.fields[0] = "front"
            note.fields[1] = "back"
            try backend.invoke(.addNote(template: note, deckId: DeckID(1)))

            let populated = try backend.invoke(.graphs(search: "deck:*", days: 31))
            #expect(populated.cardCounts.includingInactive.newCards == 2)
            #expect(populated.today.answerCount == 0, "nothing has been answered yet")

            #expect(populated.rolloverHour == 4)
        }
    }

    @Test func graphs_honoursTheSearch() throws {
        try withScratchCollection("stats-search") { backend, _ in
            let names = try backend.invoke(.notetypeNames)
            let basic = try #require(names.first { $0.name == "Basic" })
            var note = try backend.invoke(.newNote(notetypeId: basic.id))
            note.fields[0] = "front"
            note.fields[1] = "back"
            try backend.invoke(.addNote(template: note, deckId: DeckID(1)))

            #expect(try backend.invoke(.graphs(search: "deck:Default", days: 31))
                .cardCounts.includingInactive.newCards == 1)
            #expect(try backend.invoke(.graphs(search: "deck:NoSuchDeck", days: 31))
                .cardCounts.includingInactive.newCards == 0)
        }
    }
}
