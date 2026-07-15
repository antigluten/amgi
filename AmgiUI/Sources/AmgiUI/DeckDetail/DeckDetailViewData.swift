public import SwiftUI

/// Pure DTO that drives `DeckDetailScreen`. The Container builds this from
/// `DeckInfo` + `DeckCounts` + `GraphsSnapshot` projections.
public struct DeckDetailViewData: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let tone: Color
    public let deckName: String
    public let tileCounts: DeckDetailTileData
    public let isFiltered: Bool
    public let isEmpty: Bool
    public let subdecks: [DeckSubdeckRowData]
    public let insights: InsightsCardData
    public let isActionInFlight: Bool

    public init(
        title: String,
        subtitle: String,
        tone: Color,
        deckName: String,
        tileCounts: DeckDetailTileData,
        isFiltered: Bool,
        isEmpty: Bool,
        subdecks: [DeckSubdeckRowData],
        insights: InsightsCardData,
        isActionInFlight: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.deckName = deckName
        self.tileCounts = tileCounts
        self.isFiltered = isFiltered
        self.isEmpty = isEmpty
        self.subdecks = subdecks
        self.insights = insights
        self.isActionInFlight = isActionInFlight
    }
}

/// State envelope: counts/tree may still be loading while the
/// `DeckDetailScreen` should render skeleton chrome.
public enum DeckDetailViewState: Equatable, Sendable {
    case loading
    case loaded(DeckDetailViewData)
}
