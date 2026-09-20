//
//  CardClient.swift
//  AnkiClients
//
//  Created by Vladimir Gusev on 27.03.2026.
//

public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct CardClient: Sendable {
    public var fetchDue: @Sendable (_ deckId: DeckID) async throws -> [CardRecord]
    public var fetchByNote: @Sendable (_ noteId: NoteID) async throws -> [CardRecord]
    public var suspend: @Sendable (_ cardId: CardID) async throws -> Void
    public var bury: @Sendable (_ cardId: CardID) async throws -> Void
    public var flag: @Sendable (_ cardId: CardID, _ value: UInt32) async throws -> Void
    public var resetToNew: @Sendable (_ cardId: CardID) async throws -> Void
    public var setDueDate: @Sendable (_ cardId: CardID, _ days: String) async throws -> Void
    public var undoLast: @Sendable () async throws -> Void
    public var getCardFlags: @Sendable (_ cardId: CardID) async throws -> UInt32
    public var hasUndoableAction: @Sendable () async throws -> Bool
    public var removeCards: @Sendable (_ cardIds: [CardID]) async throws -> Void
}

extension CardClient: TestDependencyKey {
    public static let testValue = CardClient()
}

extension DependencyValues {
    public var cardClient: CardClient {
        get { self[CardClient.self] }
        set { self[CardClient.self] = newValue }
    }
}
