import Testing
@testable import AnkiKit

@Suite("CollectionChanges")
struct CollectionChangesTests {

    @Test func defaultsAreAllFalse() {
        let changes = CollectionChanges()
        #expect(changes == CollectionChanges(
            card: false, note: false, deck: false,
            tag: false, notetype: false, studyQueues: false
        ))
        #expect(!changes.affectsDeckTree)
    }

    @Test func allSetsEveryFacet() {
        #expect(CollectionChanges.all.card)
        #expect(CollectionChanges.all.note)
        #expect(CollectionChanges.all.deck)
        #expect(CollectionChanges.all.tag)
        #expect(CollectionChanges.all.notetype)
        #expect(CollectionChanges.all.studyQueues)
        #expect(CollectionChanges.all.affectsDeckTree)
    }

    @Test func affectsDeckTreeIgnoresTagAndNotetype() {
        #expect(!CollectionChanges(tag: true, notetype: true).affectsDeckTree)
        #expect(CollectionChanges(card: true).affectsDeckTree)
        #expect(CollectionChanges(note: true).affectsDeckTree)
        #expect(CollectionChanges(deck: true).affectsDeckTree)
        #expect(CollectionChanges(studyQueues: true).affectsDeckTree)
    }

    @Test func unionORsEachFacet() {
        let merged = CollectionChanges(card: true).union(CollectionChanges(deck: true))
        #expect(merged == CollectionChanges(card: true, deck: true))
    }

    @Test func deckCreationCarriesIdAndChanges() {
        let creation = DeckCreation(id: DeckID(42), changes: CollectionChanges(deck: true))
        #expect(creation.id == DeckID(42))
        #expect(creation.changes.deck)
    }
}
