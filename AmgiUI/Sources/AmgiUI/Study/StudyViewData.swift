import Foundation

// MARK: - DTOs (no AnkiKit / AnkiClients imports — pure view data)

/// Aggregate due-card counts for the Study summary ring.
public struct StudySummaryData: Equatable, Sendable {
    public let totalDue: Int
    public let newCount: Int
    public let learnCount: Int
    public let reviewCount: Int
    /// e.g. "Today"
    public let todayLabel: String
    /// e.g. "Wednesday · 4 decks due"
    public let subtitleLabel: String
    /// Number of decks with cards due — used by ring's "across N decks" subline.
    public let deckCount: Int

    public init(
        totalDue: Int,
        newCount: Int,
        learnCount: Int,
        reviewCount: Int,
        todayLabel: String,
        subtitleLabel: String,
        deckCount: Int
    ) {
        self.totalDue = totalDue
        self.newCount = newCount
        self.learnCount = learnCount
        self.reviewCount = reviewCount
        self.todayLabel = todayLabel
        self.subtitleLabel = subtitleLabel
        self.deckCount = deckCount
    }
}

/// A single deck row in the Study "Up Next" list.
public struct StudyDeckRowData: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let name: String
    public let totalDue: Int
    public let newCount: Int
    public let learnCount: Int
    public let reviewCount: Int
    public let isFiltered: Bool

    public init(
        id: Int64,
        name: String,
        totalDue: Int,
        newCount: Int,
        learnCount: Int,
        reviewCount: Int,
        isFiltered: Bool
    ) {
        self.id = id
        self.name = name
        self.totalDue = totalDue
        self.newCount = newCount
        self.learnCount = learnCount
        self.reviewCount = reviewCount
        self.isFiltered = isFiltered
    }
}

/// A book recommendation card in the Study "Reading recommendations" horizontal strip.
public struct StudyReadingRecData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let coverImagePath: String?
    /// e.g. "ANTOINE DE SAINT-EXUPÉRY"
    public let authorLabel: String

    public init(
        id: String,
        title: String,
        coverImagePath: String? = nil,
        authorLabel: String
    ) {
        self.id = id
        self.title = title
        self.coverImagePath = coverImagePath
        self.authorLabel = authorLabel
    }
}
