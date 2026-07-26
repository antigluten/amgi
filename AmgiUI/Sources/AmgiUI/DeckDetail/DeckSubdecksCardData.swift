import Foundation

/// Pure DTO for a row in the Subdecks card. AmgiUI stays decoupled from
/// AnkiKit's `DeckTreeNode` — Containers map from the tree.
public struct DeckSubdeckRowData: Equatable, Hashable, Identifiable, Sendable {
    public let id: Int64
    public let name: String
    public let fullName: String
    public let newCount: Int
    public let learnCount: Int
    public let reviewCount: Int
    public let isFiltered: Bool

    public init(
        id: Int64,
        name: String,
        fullName: String,
        newCount: Int,
        learnCount: Int,
        reviewCount: Int,
        isFiltered: Bool
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.newCount = newCount
        self.learnCount = learnCount
        self.reviewCount = reviewCount
        self.isFiltered = isFiltered
    }
}
