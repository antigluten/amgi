//
//  AmgiDeckEntity.swift
//  IntentsFeature
//
//  Created by Vladimir Gusev on 19.09.2026.
//

import AppCore
public import AppIntents
import Foundation

public struct AmgiDeckEntity: AppEntity {
    /// `String(deckId)` — `Int64` does not conform to `EntityIdentifier`.
    public var id: String
    public var name: String

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Deck"
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    public static let defaultQuery = AmgiDeckEntityQuery()

    var deckId: Int64? { Int64(id) }
}

public struct AmgiDeckEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [AmgiDeckEntity] {
        Self.allDecks().filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [AmgiDeckEntity] {
        Self.allDecks()
    }

    static func allDecks() -> [AmgiDeckEntity] {
        WidgetSnapshotStore.allSnapshots()
            .filter { $0.deckId != 0 }
            .map { AmgiDeckEntity(id: String($0.deckId), name: $0.deckName) }
    }
}
