//
//  DueCountIntent.swift
//  IntentsFeature
//
//  Created by Vladimir Gusev on 19.09.2026.
//

import AppCore
public import AppIntents
import Foundation

public struct DueCountIntent: AppIntent {
    public init() {}

    public static let title: LocalizedStringResource = "Get Cards Due"
    public static let description = IntentDescription(
        "Reports how many cards are waiting for review.",
        categoryName: "Review"
    )
    public static let openAppWhenRun = false

    @Parameter(title: "Deck")
    public var deck: AmgiDeckEntity?

    public static var parameterSummary: some ParameterSummary {
        Summary("Get cards due in \(\.$deck)")
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let deckId = deck.map { $0.deckId ?? 0 } ?? 0
        guard let snapshot = WidgetSnapshotStore.read(deckId: deckId) else {
            throw AmgiIntentError.noSnapshot
        }
        let due = snapshot.totalDue
        return .result(
            value: due,
            dialog: due == 0
                ? "Nothing due in \(snapshot.deckName)."
                : "^[\(due) card](inflect: true) due in \(snapshot.deckName)."
        )
    }
}
