import AppCore
import Testing
@testable import WidgetFeature

struct WidgetConfigurationTests {
    @Test
    func missingDeckStillResolvesSoTimelineCanFallBack() async throws {
        let missingID = Int64.max
        #expect(WidgetSnapshotStore.read(deckId: missingID) == nil)
        let entities = try await DeckEntityQuery().entities(for: [String(missingID)])
        #expect(entities.map(\.id) == [String(missingID)])
        #expect(entities.first?.name == "All Decks")
    }
}
