import Foundation

/// Pure value type that drives `InsightsCard`. Containers project the raw
/// stats response into this so AmgiUI stays free of AnkiProto / GraphsSnapshot.
public struct InsightsCardData: Equatable, Hashable, Sendable {
    /// `nil` ⇒ no reviewed cards in the 30-day window → render as `—`.
    public let retention30dPercent: Int?
    /// `nil` ⇒ no reviews in the window → render as `—`.
    public let avgCardsPerDay: Int?
    public let matureCards: Int

    public init(retention30dPercent: Int?, avgCardsPerDay: Int?, matureCards: Int) {
        self.retention30dPercent = retention30dPercent
        self.avgCardsPerDay = avgCardsPerDay
        self.matureCards = matureCards
    }

    public static let empty = InsightsCardData(
        retention30dPercent: nil,
        avgCardsPerDay: nil,
        matureCards: 0
    )
}
