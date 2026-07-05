/// Which Collection facets a mutation touched. Decoded from the Engine's
/// `OpChanges` response by AnkiProtoBridge and consumed by the app's
/// CollectionStore to invalidate cached reads (see CONTEXT.md:
/// CollectionChanges, Invalidation).
public struct CollectionChanges: Equatable, Sendable {
    public var card: Bool
    public var note: Bool
    public var deck: Bool
    public var tag: Bool
    public var notetype: Bool
    public var studyQueues: Bool

    public init(
        card: Bool = false,
        note: Bool = false,
        deck: Bool = false,
        tag: Bool = false,
        notetype: Bool = false,
        studyQueues: Bool = false
    ) {
        self.card = card
        self.note = note
        self.deck = deck
        self.tag = tag
        self.notetype = notetype
        self.studyQueues = studyQueues
    }

    /// Conservative "everything changed" — used after sync, import, and
    /// review sessions, where no single OpChanges payload is available.
    public static let all = CollectionChanges(
        card: true, note: true, deck: true,
        tag: true, notetype: true, studyQueues: true
    )

    /// True when any facet the cached deck tree (names + due counts)
    /// depends on changed.
    public var affectsDeckTree: Bool {
        deck || card || note || studyQueues
    }

    public func union(_ other: CollectionChanges) -> CollectionChanges {
        CollectionChanges(
            card: card || other.card,
            note: note || other.note,
            deck: deck || other.deck,
            tag: tag || other.tag,
            notetype: notetype || other.notetype,
            studyQueues: studyQueues || other.studyQueues
        )
    }
}

/// Result of creating a deck: the new id plus the invalidation payload.
public struct DeckCreation: Equatable, Sendable {
    public let id: DeckID
    public let changes: CollectionChanges

    public init(id: DeckID, changes: CollectionChanges) {
        self.id = id
        self.changes = changes
    }
}
