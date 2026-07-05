import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto

@Suite("CollectionChanges proto conversion")
struct CollectionChangesProtoTests {

    @Test func mapsEachTrackedFacet() {
        var proto = Anki_Collection_OpChanges()
        proto.card = true
        proto.deck = true
        proto.studyQueues = true
        let changes = CollectionChanges(proto)
        #expect(changes == CollectionChanges(card: true, deck: true, studyQueues: true))
    }

    @Test func untrackedProtoFlagsAreDropped() {
        var proto = Anki_Collection_OpChanges()
        proto.config = true          // not tracked
        proto.browserTable = true    // not tracked
        let changes = CollectionChanges(proto)
        #expect(changes == CollectionChanges())
    }
}
