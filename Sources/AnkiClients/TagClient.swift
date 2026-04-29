public import Dependencies
import DependenciesMacros

@DependencyClient
public struct TagClient: Sendable {
    public var getAllTags: @Sendable () throws -> [String]
    public var addTag: @Sendable (_ tag: String) throws -> Void
    public var addTagToNotes: @Sendable (_ tag: String, _ noteIDs: [Int64]) throws -> Void
    public var removeTagFromNotes: @Sendable (_ tag: String, _ noteIDs: [Int64]) throws -> Void
    public var removeTag: @Sendable (_ tag: String) throws -> Void
    public var renameTag: @Sendable (_ oldName: String, _ newName: String) throws -> Void
    public var findNotesByTag: @Sendable (_ tag: String) throws -> [Int64]
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
