public struct DeckInfo: Sendable, Equatable, Identifiable, Hashable {
    public let id: Int64
    public var name: String
    public var counts: DeckCounts
    public var isFiltered: Bool

    public init(id: Int64, name: String, counts: DeckCounts = .zero, isFiltered: Bool = false) {
        self.id = id
        self.name = name
        self.counts = counts
        self.isFiltered = isFiltered
    }
}

public struct DeckTreeNode: Sendable, Equatable, Identifiable {
    public let id: Int64
    public var name: String
    public var fullName: String
    public var counts: DeckCounts
    public var isFiltered: Bool
    public var children: [DeckTreeNode]

    public init(
        id: Int64,
        name: String,
        fullName: String,
        counts: DeckCounts = .zero,
        isFiltered: Bool = false,
        children: [DeckTreeNode] = []
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.counts = counts
        self.isFiltered = isFiltered
        self.children = children
    }
}

public struct DeckCounts: Sendable, Equatable, Hashable {
    public var newCount: Int
    public var learnCount: Int
    public var reviewCount: Int

    public var total: Int { newCount + learnCount + reviewCount }

    public static let zero = DeckCounts(newCount: 0, learnCount: 0, reviewCount: 0)

    public init(newCount: Int, learnCount: Int, reviewCount: Int) {
        self.newCount = newCount
        self.learnCount = learnCount
        self.reviewCount = reviewCount
    }
}
