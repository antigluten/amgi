import Foundation
import Testing
import AppCore
@testable import WidgetFeature

struct WidgetConfigurationTests {
    private let empty = DeckEntityQuery(snapshots: { [] })

    @Test
    func allDecksResolvesBeforeFirstSnapshot() async throws {
        let entities = try await empty.entities(for: ["0"])
        #expect(entities.map(\.id) == ["0"])
        #expect(entities.first?.name == "All Decks")
    }

    @Test
    func snapshotBackedDecksResolveInOrderAndSkipUnknown() async throws {
        let query = DeckEntityQuery(snapshots: { [
            WidgetSnapshot(deckId: 0, deckName: "Everything", newCount: 0, learnCount: 0, reviewCount: 0,
                           reviewedToday: 0, streak: 0, lastSevenDays: [], snapshotDate: .now),
            WidgetSnapshot(deckId: 42, deckName: "Japanese", newCount: 0, learnCount: 0, reviewCount: 0,
                           reviewedToday: 0, streak: 0, lastSevenDays: [], snapshotDate: .now),
        ] })
        let entities = try await query.entities(for: ["42", "7", "0"])
        #expect(entities.map(\.id) == ["42", "0"])
        #expect(entities.map(\.name) == ["Japanese", "Everything"])
    }

    @Test
    func unknownDeckIsOmitted() async throws {
        #expect(try await empty.entities(for: ["42", String(Int64.max), "not-a-deck"]).isEmpty)
    }
}
