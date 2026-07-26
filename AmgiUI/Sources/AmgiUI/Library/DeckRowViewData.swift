import Foundation

/// Anki-agnostic view data for a single Library deck row. Containers
/// map from their domain model (e.g. AnkiKit's `DeckListRow`) to this
/// type so AmgiUI doesn't link the Anki backend.
public struct DeckRowViewData: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int64
    public let name: String        // last path segment, e.g. "한국어"
    public let fullName: String    // full path, e.g. "Languages::한국어"
    public let newCount: Int
    public let learnCount: Int
    public let reviewCount: Int
    public let isFiltered: Bool
    public let subdeckCount: Int

    public init(
        id: Int64,
        name: String,
        fullName: String,
        newCount: Int,
        learnCount: Int,
        reviewCount: Int,
        isFiltered: Bool,
        subdeckCount: Int
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.newCount = newCount
        self.learnCount = learnCount
        self.reviewCount = reviewCount
        self.isFiltered = isFiltered
        self.subdeckCount = subdeckCount
    }

    public var totalCount: Int { newCount + learnCount + reviewCount }
}
