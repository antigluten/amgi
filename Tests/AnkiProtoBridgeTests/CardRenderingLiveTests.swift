//
//  CardRenderingLiveTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

@Suite struct CardRenderingLiveTests {
    @Test func renderUncommittedCard_rendersSampleFieldsThroughATemplate() throws {
        try withScratchCollection("render-uncommitted") { backend, _ in
            let names = try backend.invoke(.notetypeNames)
            let basic = try #require(names.first { $0.name == "Basic" })
            let notetype = try backend.invoke(.notetype(for: basic.id))
            let template = try #require(notetype.templates.first)

            let rendered = try backend.invoke(
                .renderUncommittedCard(
                    notetypeId: basic.id,
                    template: template,
                    cardOrd: 0,
                    sampleFields: ["SAMPLE-FRONT", "SAMPLE-BACK"]
                )
            )
            #expect(rendered.frontHTML.contains("SAMPLE-FRONT"))
            #expect(rendered.backHTML.contains("SAMPLE-BACK"))
        }
    }

    @Test func extractClozeForTyping_pullsTheNumberedDeletion() throws {
        try withScratchCollection("render-cloze") { backend, _ in
            let text = "The capital is {{c1::Paris}} and the river is {{c2::Seine}}"
            let first = try backend.invoke(.extractClozeForTyping(text: text, ordinal: 1))
            let second = try backend.invoke(.extractClozeForTyping(text: text, ordinal: 2))
            #expect(first == "Paris")
            #expect(second == "Seine")
        }
    }

    @Test func getEmptyCardsReport_findsANoteBlankedToNothing() throws {
        try withScratchCollection("render-empty") { backend, _ in
            #expect(try backend.invoke(.getEmptyCardsReport).notes.isEmpty)

            let names = try backend.invoke(.notetypeNames)
            let basic = try #require(names.first { $0.name == "Basic" })
            var template = try backend.invoke(.newNote(notetypeId: basic.id))
            template.fields[0] = "front"
            template.fields[1] = "back"
            try backend.invoke(.addNote(template: template, deckId: DeckID(1)))

            let id = try #require(try backend.invoke(.searchNoteIds(query: "front")).first)
            var note = try backend.invoke(.getNote(id: id))
            note.flds = "\u{1f}back"
            try backend.invoke(.updateNote(note))

            let report = try backend.invoke(.getEmptyCardsReport)
            #expect(report.notes.count == 1)
            #expect(report.notes.first?.noteID == id)
        }
    }
}
