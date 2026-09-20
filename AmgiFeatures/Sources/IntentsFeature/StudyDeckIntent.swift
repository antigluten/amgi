//
//  StudyDeckIntent.swift
//  IntentsFeature
//
//  Created by Vladimir Gusev on 19.09.2026.
//

public import AppIntents
import Foundation

/// "Study Korean in Amgi" — opens the app straight into the reviewer.
public struct StudyDeckIntent: AppIntent {
    public init() {}

    public static let title: LocalizedStringResource = "Study Deck"
    public static let description = IntentDescription(
        "Opens Amgi and starts reviewing a deck.",
        categoryName: "Review"
    )
    public static let openAppWhenRun = true

    @Parameter(title: "Deck")
    public var deck: AmgiDeckEntity

    public static var parameterSummary: some ParameterSummary {
        Summary("Study \(\.$deck)")
    }

    public func perform() async throws -> some IntentResult & OpensIntent {
        guard let deckId = deck.deckId,
              let url = URL(string: "amgi://review?deckId=\(deckId)")
        else { throw AmgiIntentError.badDeckId }
        return .result(opensIntent: OpenURLIntent(url))
    }
}
