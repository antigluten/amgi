import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

/// Live end-to-end check of the typed-answer mechanic against the real Rust
/// backend: a fresh collection's stock "Basic (type in the answer)" notetype
/// renders the `[[type:Back]]` placeholder ReviewSession keys off, and
/// CompareAnswer produces the diff markup substituted into the back HTML.
@Suite struct TypedAnswerLiveTests {
    @Test func basicTypeInAnswer_rendersPlaceholder_and_diffsTypedAnswer() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("typed-answer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let backend = try AnkiBackend()
        try backend.openCollection(
            collectionPath: dir.appendingPathComponent("collection.anki2").path,
            mediaFolderPath: dir.appendingPathComponent("media").path,
            mediaDbPath: dir.appendingPathComponent("media.db").path
        )
        defer { try? backend.closeCollection() }

        let names = try backend.invoke(.notetypeNames)
        let typeIn = try #require(
            names.first { $0.name == "Basic (type in the answer)" },
            "fresh collection should contain the stock type-in notetype"
        )

        var template = try backend.invoke(.newNote(notetypeId: typeIn.id))
        try #require(template.fields.count >= 2)
        template.fields[0] = "What is the capital of France?"
        template.fields[1] = "Paris"
        try backend.invoke(.addNote(template: template, deckId: DeckID(1)))

        let queued: QueuedCardsResult = try backend.invoke(.getQueuedCards(fetchLimit: 1))
        let card = try #require(queued.cards.first?.card)
        let rendered = try backend.invoke(.renderExistingCard(cardId: card.id))

        // Front carries the placeholder ReviewSession swaps for <input id=typeans>;
        // back carries the same token where the CompareAnswer diff is substituted.
        #expect(rendered.frontHTML.contains("[[type:Back]]"))
        #expect(rendered.backHTML.contains("[[type:Back]]"))

        let correct: String = try backend.invoke(
            .compareAnswer(expected: "Paris", provided: "Paris", combining: true)
        )
        #expect(correct.contains("typeGood"))

        let wrong: String = try backend.invoke(
            .compareAnswer(expected: "Paris", provided: "Pariz", combining: true)
        )
        #expect(wrong.contains("typeBad"))
    }
}
