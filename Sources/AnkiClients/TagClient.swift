public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct TagClient: Sendable {
    public var getAllTags: @Sendable () async throws -> [String]
    public var addTag: @Sendable (_ tag: String) async throws -> Void
    public var addTagToNotes: @Sendable (_ tag: String, _ noteIDs: [NoteID]) async throws -> Void
    public var removeTagFromNotes: @Sendable (_ tag: String, _ noteIDs: [NoteID]) async throws -> Void
    public var removeTag: @Sendable (_ tag: String) async throws -> Void
    public var renameTag: @Sendable (_ oldName: String, _ newName: String) async throws -> Void
    public var findNotesByTag: @Sendable (_ tag: String) async throws -> [NoteID]
}

extension TagClient: TestDependencyKey {
    public static let testValue = TagClient()
}

extension DependencyValues {
    public var tagClient: TagClient {
        get { self[TagClient.self] }
        set { self[TagClient.self] = newValue }
    }
}
