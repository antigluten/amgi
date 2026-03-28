public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct NoteClient: Sendable {
    public var fetch: @Sendable (_ noteId: Int64) throws -> NoteRecord?
    public var search: @Sendable (_ query: String, _ limit: Int?) throws -> [NoteRecord]
    public var save: @Sendable (_ note: NoteRecord) throws -> Void
    public var delete: @Sendable (_ noteId: Int64) throws -> Void
}

extension NoteClient: TestDependencyKey {
    public static let testValue = NoteClient()
}

extension DependencyValues {
    public var noteClient: NoteClient {
        get { self[NoteClient.self] }
        set { self[NoteClient.self] = newValue }
    }
}
