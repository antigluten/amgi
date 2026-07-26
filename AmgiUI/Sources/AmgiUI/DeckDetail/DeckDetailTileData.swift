import Foundation

/// Anki-agnostic payload for the deck-detail counts tile.
/// Only carries the three due-counts — no FSRS or domain types.
/// Containers map from `DeckCounts` to this type so AmgiUI stays
/// free of AnkiKit imports.
public struct DeckDetailTileData: Equatable, Hashable, Sendable {
    public let newCount: Int
    public let learnCount: Int
    public let reviewCount: Int

    public init(newCount: Int, learnCount: Int, reviewCount: Int) {
        self.newCount = newCount
        self.learnCount = learnCount
        self.reviewCount = reviewCount
    }

    public static let zero = DeckDetailTileData(newCount: 0, learnCount: 0, reviewCount: 0)
}
