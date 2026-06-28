import Testing
import Foundation
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto
private import SwiftProtobuf

@Suite struct DecksRequestsTests {
    // MARK: - setCurrentDeck / renameDeck / removeDecks (Void)

    @Test func setCurrentDeck_dispatches_and_encodes_deckId() throws {
        let envelope: Request<Void> = .setCurrentDeck(deckId: DeckID(42))
        #expect(envelope.serviceId == ServiceID.decks)
        #expect(envelope.methodId == DecksMethod.setCurrentDeck)
        let proto = try Anki_Decks_DeckId(serializedBytes: envelope.body)
        #expect(proto.did == 42)
    }

    @Test func renameDeck_dispatches_and_encodes_fields() throws {
        let envelope: Request<Void> = .renameDeck(deckId: DeckID(7), newName: "Korean::Verbs")
        #expect(envelope.serviceId == ServiceID.decks)
        #expect(envelope.methodId == DecksMethod.renameDeck)
        let proto = try Anki_Decks_RenameDeckRequest(serializedBytes: envelope.body)
        #expect(proto.deckID == 7)
        #expect(proto.newName == "Korean::Verbs")
    }

    @Test func removeDecks_dispatches_and_encodes_id_list() throws {
        let envelope: Request<Void> = .removeDecks(deckIds: [DeckID(1), DeckID(2), DeckID(3)])
        #expect(envelope.serviceId == ServiceID.decks)
        #expect(envelope.methodId == DecksMethod.removeDecks)
        let proto = try Anki_Decks_DeckIds(serializedBytes: envelope.body)
        #expect(proto.dids == [1, 2, 3])
    }

    // MARK: - getCurrentDeck

    @Test func getCurrentDeck_dispatches_with_empty_body() throws {
        let envelope: Request<DeckInfo> = .getCurrentDeck
        #expect(envelope.serviceId == ServiceID.decks)
        #expect(envelope.methodId == DecksMethod.getCurrentDeck)
        #expect(try envelope.body.isEmpty)
    }

    @Test func getCurrentDeck_decodes_into_DeckInfo() throws {
        var deck = Anki_Decks_Deck()
        deck.id = 100
        deck.name = "Korean"
        let bytes = try deck.serializedData()
        let envelope: Request<DeckInfo> = .getCurrentDeck
        let info = try envelope.decode(bytes)
        #expect(info.id == DeckID(100))
        #expect(info.name == "Korean")
    }

    // MARK: - newDeck / addDeck (two-phase)

    @Test func newDeck_dispatches_with_empty_body() throws {
        let envelope: Request<DeckTemplate> = .newDeck
        #expect(envelope.serviceId == ServiceID.decks)
        #expect(envelope.methodId == DecksMethod.newDeck)
        #expect(try envelope.body.isEmpty)
    }

    @Test func newDeck_decodes_bytes_into_opaque_template() throws {
        var deck = Anki_Decks_Deck()
        deck.id = 0
        deck.name = ""
        let bytes = try deck.serializedData()
        let envelope: Request<DeckTemplate> = .newDeck
        let template = try envelope.decode(bytes)
        // Round-trip preserves the original byte payload.
        #expect(template.bytes == bytes)
    }

    @Test func addDeck_renames_template_and_encodes_for_addDeck() throws {
        var deck = Anki_Decks_Deck()
        deck.id = 0
        deck.name = "default-name"
        let templateBytes = try deck.serializedData()
        let template = DeckTemplate(bytes: templateBytes)

        let envelope: Request<DeckID> = .addDeck(template: template, name: "Korean")
        #expect(envelope.serviceId == ServiceID.decks)
        #expect(envelope.methodId == DecksMethod.addDeck)
        let proto = try Anki_Decks_Deck(serializedBytes: envelope.body)
        #expect(proto.name == "Korean")
    }

    @Test func addDeck_decodes_OpChangesWithId_into_DeckID() throws {
        var resp = Anki_Collection_OpChangesWithId()
        resp.id = 12345
        let bytes = try resp.serializedData()

        let template = DeckTemplate(bytes: Data())
        let envelope: Request<DeckID> = .addDeck(template: template, name: "x")
        #expect(try envelope.decode(bytes) == DeckID(12345))
    }

    // MARK: - existing deckNames coverage

    @Test func deckNames_dispatches_to_decks_service_getDeckNames_method() {
        let request: Request<[DeckInfo]> = .deckNames
        #expect(request.serviceId == ServiceID.decks)
        #expect(request.methodId == DecksMethod.getDeckNames)
    }

    @Test func deckNames_decode_maps_proto_entries_to_DeckInfo_with_typed_ids() throws {
        var proto = Anki_Decks_DeckNames()
        var first = Anki_Decks_DeckNameId()
        first.id = 42
        first.name = "Default"
        var second = Anki_Decks_DeckNameId()
        second.id = 100
        second.name = "Korean"
        proto.entries = [first, second]

        let bytes = try proto.serializedData()
        let request: Request<[DeckInfo]> = .deckNames
        let decoded = try request.decode(bytes)

        #expect(decoded.count == 2)
        #expect(decoded[0].id == DeckID(42))
        #expect(decoded[0].name == "Default")
        #expect(decoded[1].id == DeckID(100))
        #expect(decoded[1].name == "Korean")
    }

    // MARK: - deckTree

    @Test func deckTree_dispatches_to_decks_service_getDeckTree_method() {
        let request: Request<[DeckTreeNode]> = .deckTree()
        #expect(request.serviceId == ServiceID.decks)
        #expect(request.methodId == DecksMethod.getDeckTree)
    }

    @Test func deckTree_encodes_now_timestamp_in_body() throws {
        let instant = Date(timeIntervalSince1970: 1_700_000_000)
        let request: Request<[DeckTreeNode]> = .deckTree(at: instant)
        let body = try Anki_Decks_DeckTreeRequest(serializedBytes: request.body)
        #expect(body.now == 1_700_000_000)
    }

    @Test func deckTree_drops_synthetic_root_and_joins_full_paths() throws {
        // Synthetic root with one top-level deck "Korean" containing "Vocab".
        var vocab = Anki_Decks_DeckTreeNode()
        vocab.deckID = 200
        vocab.name = "Vocab"
        vocab.newCount = 4
        vocab.learnCount = 1
        vocab.reviewCount = 7

        var korean = Anki_Decks_DeckTreeNode()
        korean.deckID = 100
        korean.name = "Korean"
        korean.children = [vocab]

        var root = Anki_Decks_DeckTreeNode()
        root.deckID = 0
        root.children = [korean]

        let bytes = try root.serializedData()
        let decoded = try Request<[DeckTreeNode]>.deckTree().decode(bytes)

        #expect(decoded.count == 1)
        let top = try #require(decoded.first)
        #expect(top.id == DeckID(100))
        #expect(top.name == "Korean")
        #expect(top.fullName == "Korean")
        #expect(top.children.count == 1)

        let child = top.children[0]
        #expect(child.id == DeckID(200))
        #expect(child.fullName == "Korean::Vocab")
        #expect(child.counts == DeckCounts(newCount: 4, learnCount: 1, reviewCount: 7))
    }

    // MARK: - deckCounts

    @Test func deckCounts_dispatches_to_decks_service_getDeckTree_method() {
        let request: Request<DeckCounts?> = .deckCounts(for: DeckID(42))
        #expect(request.serviceId == ServiceID.decks)
        #expect(request.methodId == DecksMethod.getDeckTree)
    }

    @Test func deckCounts_returns_counts_for_matching_node() throws {
        var vocab = Anki_Decks_DeckTreeNode()
        vocab.deckID = 200
        vocab.name = "Vocab"
        vocab.newCount = 4
        vocab.learnCount = 1
        vocab.reviewCount = 7
        var korean = Anki_Decks_DeckTreeNode()
        korean.deckID = 100
        korean.name = "Korean"
        korean.children = [vocab]
        var root = Anki_Decks_DeckTreeNode()
        root.children = [korean]

        let bytes = try root.serializedData()
        let decoded = try Request<DeckCounts?>.deckCounts(for: DeckID(200)).decode(bytes)

        #expect(decoded == DeckCounts(newCount: 4, learnCount: 1, reviewCount: 7))
    }

    @Test func deckCounts_returns_nil_when_deck_missing() throws {
        var korean = Anki_Decks_DeckTreeNode()
        korean.deckID = 100
        korean.name = "Korean"
        var root = Anki_Decks_DeckTreeNode()
        root.children = [korean]

        let bytes = try root.serializedData()
        let decoded = try Request<DeckCounts?>.deckCounts(for: DeckID(999)).decode(bytes)

        #expect(decoded == nil)
    }
}
