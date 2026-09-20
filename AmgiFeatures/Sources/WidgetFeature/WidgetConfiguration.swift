//
//  WidgetConfiguration.swift
//  WidgetFeature
//
//  Created by Vladimir Gusev on 07.04.2026.
//

import AppIntents
import WidgetKit
import Foundation
import AppCore

struct DeckEntity: AppEntity {
    var id: String        // String(deckId) — Int64 doesn't conform to EntityIdentifier
    var name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Deck"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static let defaultQuery = DeckEntityQuery()
}

struct DeckEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DeckEntity] {
        WidgetSnapshotStore.allSnapshots().compactMap { snapshot in
            guard identifiers.contains(String(snapshot.deckId)) else { return nil }
            return DeckEntity(id: String(snapshot.deckId), name: snapshot.deckName)
        }
    }

    func suggestedEntities() async throws -> [DeckEntity] {
        WidgetSnapshotStore.allSnapshots().map { snapshot in
            DeckEntity(id: String(snapshot.deckId), name: snapshot.deckName)
        }
    }

    func defaultResult() async -> DeckEntity? {
        // Prefer the "All Decks" aggregate; fall back to first available snapshot
        let snapshots = WidgetSnapshotStore.allSnapshots()
        if let allDecks = snapshots.first(where: { $0.deckId == 0 }) {
            return DeckEntity(id: String(allDecks.deckId), name: allDecks.deckName)
        }
        if let first = snapshots.first {
            return DeckEntity(id: String(first.deckId), name: first.deckName)
        }
        return DeckEntity(id: "0", name: "All Decks")
    }
}

struct AmgiWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Deck"
    static let description = IntentDescription("Select which deck to display.")

    @Parameter(title: "Deck")
    var deck: DeckEntity?
}
