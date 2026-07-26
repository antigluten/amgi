import Testing
import Foundation
@testable import AnkiKit

@Suite struct IdentifiersTests {
    @Test func deckID_wraps_raw_value() {
        let id = DeckID(42)
        #expect(id.rawValue == 42)
    }

    @Test func deckID_and_noteID_are_distinct_types() {
        // This is a compile-time guarantee; the runtime body just records intent.
        let deck = DeckID(1)
        let note = NoteID(1)
        #expect(deck.rawValue == note.rawValue)
        // The next two lines must NOT compile if uncommented:
        // let _: DeckID = note
        // let _: NoteID = deck
    }

    @Test func entityID_is_hashable() {
        let set: Set<DeckID> = [DeckID(1), DeckID(2), DeckID(1)]
        #expect(set.count == 2)
    }

    @Test func entityID_round_trips_through_codable() throws {
        let original = CardID(123_456_789)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CardID.self, from: data)
        #expect(decoded == original)
    }

    @Test func entityID_is_rawRepresentable() {
        let id = NotetypeID(rawValue: 7)
        #expect(id.rawValue == 7)
    }
}
