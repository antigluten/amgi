public import Foundation
public import AnkiBackend
public import AnkiKit
package import AnkiProto
import SwiftProtobuf

extension Request where Response == [DeckInfo] {
    /// Lists every deck by id and name. Skips the empty default deck and
    /// excludes filtered decks — same defaults as the legacy direct-RPC
    /// fallback in `DecksService.fetchAll`.
    public static var deckNames: Self {
        Self(
            serviceId: ServiceID.decks,
            methodId: DecksMethod.getDeckNames,
            encode: {
                // GetDeckNamesRequest with default flags (skip_empty_default=false,
                // include_filtered=false). An empty body would skip both fields
                // which is functionally equivalent for the proto3 wire format.
                try Anki_Decks_GetDeckNamesRequest().serializedData()
            },
            decode: { bytes in
                let resp = try Anki_Decks_DeckNames(serializedBytes: bytes)
                return resp.entries.map { entry in
                    DeckInfo(id: DeckID(entry.id), name: entry.name)
                }
            }
        )
    }
}

extension Request where Response == [DeckTreeNode] {
    /// Returns the top-level deck-tree nodes (i.e. the children of the
    /// synthetic root) with `fullName` paths populated.
    ///
    /// - Parameter at: timestamp passed to the backend for count
    ///   computation. Defaults to "now". Pass `.distantPast` (or any
    ///   `Date(timeIntervalSince1970: 0)`) to skip count computation.
    public static func deckTree(at instant: Date = Date()) -> Self {
        Self(
            serviceId: ServiceID.decks,
            methodId: DecksMethod.getDeckTree,
            encode: {
                var proto = Anki_Decks_DeckTreeRequest()
                proto.now = Int64(instant.timeIntervalSince1970)
                return try proto.serializedData()
            },
            decode: { bytes in
                let root = try Anki_Decks_DeckTreeNode(serializedBytes: bytes)
                return root.children.map { DeckTreeNode($0) }
            }
        )
    }
}

extension Request where Response == DeckCounts? {
    /// Returns the `DeckCounts` for the named deck by issuing a
    /// `getDeckTree` and finding the matching node. Mirrors the existing
    /// `DecksService.countsForDeck` behaviour. Returns `nil` if the deck
    /// is not present in the tree.
    public static func deckCounts(for id: DeckID) -> Self {
        Self(
            serviceId: ServiceID.decks,
            methodId: DecksMethod.getDeckTree,
            encode: {
                var proto = Anki_Decks_DeckTreeRequest()
                proto.now = Int64(Date().timeIntervalSince1970)
                return try proto.serializedData()
            },
            decode: { bytes in
                let root = try Anki_Decks_DeckTreeNode(serializedBytes: bytes)
                guard let node = findNode(in: root, deckId: id.rawValue) else { return nil }
                return DeckCounts(
                    newCount: Int(node.newCount),
                    learnCount: Int(node.learnCount),
                    reviewCount: Int(node.reviewCount)
                )
            }
        )
    }
}

private func findNode(in node: Anki_Decks_DeckTreeNode, deckId: Int64) -> Anki_Decks_DeckTreeNode? {
    if node.deckID == deckId { return node }
    for child in node.children {
        if let hit = findNode(in: child, deckId: deckId) { return hit }
    }
    return nil
}

// MARK: - setCurrentDeck

extension Request where Response == Void {
    /// Marks the deck as the current deck for the open collection.
    public static func setCurrentDeck(deckId: DeckID) -> Self {
        Self(
            serviceId: ServiceID.decks,
            methodId: DecksMethod.setCurrentDeck,
            encode: {
                var proto = Anki_Decks_DeckId()
                proto.did = deckId.rawValue
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Renames a deck in place.
    public static func renameDeck(deckId: DeckID, newName: String) -> Self {
        Self(
            serviceId: ServiceID.decks,
            methodId: DecksMethod.renameDeck,
            encode: {
                var proto = Anki_Decks_RenameDeckRequest()
                proto.deckID = deckId.rawValue
                proto.newName = newName
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Removes the given deck(s). The Anki backend cascades to children
    /// and their cards.
    public static func removeDecks(deckIds: [DeckID]) -> Self {
        Self(
            serviceId: ServiceID.decks,
            methodId: DecksMethod.removeDecks,
            encode: {
                var proto = Anki_Decks_DeckIds()
                proto.dids = deckIds.map(\.rawValue)
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }
}

// MARK: - getCurrentDeck

extension Request where Response == DeckInfo {
    /// Returns the deck currently selected as "current" in the collection.
    public static var getCurrentDeck: Self {
        .empty(
            serviceId: ServiceID.decks,
            methodId: DecksMethod.getCurrentDeck,
            decode: { bytes in
                let proto = try Anki_Decks_Deck(serializedBytes: bytes)
                return DeckInfo(id: DeckID(proto.id), name: proto.name)
            }
        )
    }
}

// MARK: - addDeck (two-phase create)

extension Request where Response == DeckTemplate {
    /// Returns a server-prepared blank deck template (carries the
    /// backend's default field values opaquely). Pair with
    /// `Request.addDeck(template:name:)` to persist.
    public static var newDeck: Self {
        .empty(
            serviceId: ServiceID.decks,
            methodId: DecksMethod.newDeck,
            decode: { bytes in DeckTemplate(bytes: bytes) }
        )
    }
}

extension Request where Response == DeckID {
    /// Renames the given template to `name` and persists it. Returns
    /// the new deck's id.
    public static func addDeck(template: DeckTemplate, name: String) -> Self {
        Self(
            serviceId: ServiceID.decks,
            methodId: DecksMethod.addDeck,
            encode: {
                var proto = try Anki_Decks_Deck(serializedBytes: template.bytes)
                proto.name = name
                return try proto.serializedData()
            },
            decode: { bytes in
                let resp = try Anki_Collection_OpChangesWithId(serializedBytes: bytes)
                return DeckID(resp.id)
            }
        )
    }
}

extension DeckTreeNode {
    /// Maps a proto deck-tree node into the `AnkiKit` mirror, joining
    /// `fullName` paths recursively. `parentPath` is the joined path of
    /// every ancestor — pass `""` for top-level decks.
    package init(_ proto: Anki_Decks_DeckTreeNode, parentPath: String = "") {
        let fullName = parentPath.isEmpty ? proto.name : "\(parentPath)::\(proto.name)"
        self.init(
            id: DeckID(proto.deckID),
            name: proto.name,
            fullName: fullName,
            counts: DeckCounts(
                newCount: Int(proto.newCount),
                learnCount: Int(proto.learnCount),
                reviewCount: Int(proto.reviewCount)
            ),
            isFiltered: proto.filtered,
            children: proto.children.map { DeckTreeNode($0, parentPath: fullName) }
        )
    }
}
