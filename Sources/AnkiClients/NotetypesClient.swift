public import AnkiProto
public import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct NotetypesClient: Sendable {
    /// Lists all notetype names + ids without expanding to full notetypes.
    public var listAll: @Sendable () throws -> [Anki_Notetypes_NotetypeNameId]

    /// Fetches a notetype as the raw proto for editing.
    public var getRaw: @Sendable (_ id: Int64) throws -> Anki_Notetypes_Notetype

    /// Persists a modified notetype back to the collection.
    public var update: @Sendable (_ notetype: Anki_Notetypes_Notetype) throws -> Void

    /// Removes a notetype (and all cards using it) from the collection.
    public var remove: @Sendable (_ id: Int64) throws -> Void
}

extension NotetypesClient: TestDependencyKey {
    public static let testValue = NotetypesClient()
}

extension DependencyValues {
    public var notetypesClient: NotetypesClient {
        get { self[NotetypesClient.self] }
        set { self[NotetypesClient.self] = newValue }
    }
}
