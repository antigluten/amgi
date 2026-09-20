//
//  CollectionOpsLiveTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

@Suite struct CollectionOpsLiveTests {
    @Test func undoStack_tracksAMutation() throws {
        try withScratchCollection("collection-undo") { backend, _ in
            #expect(try backend.invoke(.hasUndoableAction) == false)

            let names = try backend.invoke(.notetypeNames)
            let basic = try #require(names.first { $0.name == "Basic" })
            var template = try backend.invoke(.newNote(notetypeId: basic.id))
            template.fields[0] = "undo me"
            template.fields[1] = "back"
            try backend.invoke(.addNote(template: template, deckId: DeckID(1)))

            #expect(try backend.invoke(.hasUndoableAction) == true)
            #expect(try backend.invoke(.searchNoteIds(query: "\"undo me\"")).count == 1)

            try backend.invoke(.undoLastAction)
            #expect(try backend.invoke(.searchNoteIds(query: "\"undo me\"")).isEmpty)
        }
    }

    @Test func checkDatabase_reportsACleanCollection() throws {
        try withScratchCollection("collection-check") { backend, _ in
            let problems = try backend.invoke(.checkDatabase)
            #expect(problems.isEmpty)
        }
    }

    @Test func deckConfig_readsThePresetTheDeckUses() throws {
        try withScratchCollection("collection-config") { backend, _ in
            let context = try backend.invoke(.deckConfigsForUpdate(deckId: DeckID(1)))
            let preset = try #require(context.allConfig.first?.config)
            #expect(preset.name == "Default")
            #expect(preset.config.newPerDay == 20, "Anki's stock new/day limit")
            #expect(context.currentDeck?.name == "Default")

            let direct = try backend.invoke(.deckConfig(for: preset.id))
            #expect(direct.id == preset.id)
            #expect(direct.config.newPerDay == preset.config.newPerDay)
        }
    }
}
