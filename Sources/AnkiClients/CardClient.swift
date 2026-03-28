public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct CardClient: Sendable {
    public var fetchDue: @Sendable (_ deckId: Int64) throws -> [CardRecord]
    public var fetchByNote: @Sendable (_ noteId: Int64) throws -> [CardRecord]
    public var save: @Sendable (_ card: CardRecord) throws -> Void
    public var answer: @Sendable (_ cardId: Int64, _ rating: Rating, _ timeSpent: Int32) throws -> Void
    public var undo: @Sendable (_ cardId: Int64) throws -> Void
    public var suspend: @Sendable (_ cardId: Int64) throws -> Void
    public var bury: @Sendable (_ cardId: Int64) throws -> Void
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
