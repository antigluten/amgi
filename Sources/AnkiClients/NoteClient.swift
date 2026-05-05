public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct NoteClient: Sendable {
    public var fetch: @Sendable (_ noteId: Int64) throws -> NoteRecord?
    /// Browser-friendly search — returns the first 50 hits with full
    /// fields and the rest as lazy placeholders ("Loading…" sfld) so the
    /// list doesn't stall on large results. Callers that need every
    /// record's real content (e.g. the reader's chapter loader) must
    /// use `searchAll` instead.
    public var search: @Sendable (_ query: String, _ limit: Int?) throws -> [NoteRecord]
    /// Eager search — returns full NoteRecords for every hit, no lazy
    /// placeholders. Slower for large results but required when the
    /// caller reads `flds` immediately.
    public var searchAll: @Sendable (_ query: String, _ limit: Int?) throws -> [NoteRecord]
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
