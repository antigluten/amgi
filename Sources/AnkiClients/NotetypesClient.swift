public import AnkiKit
public import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct NotetypesClient: Sendable {
    /// Lists all notetype names + ids without expanding to full notetypes.
    public var listAll: @Sendable () async throws -> [NotetypeNameId]

    /// Fetches a notetype as the AnkiKit mirror for editing.
    public var get: @Sendable (_ id: NotetypeID) async throws -> Notetype

    /// Persists a modified notetype back to the collection.
    public var update: @Sendable (_ notetype: Notetype) async throws -> Void

    /// Removes a notetype (and all cards using it) from the collection.
    public var remove: @Sendable (_ id: NotetypeID) async throws -> Void
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
