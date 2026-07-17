public import AmgiReader
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct ReaderBookClient: Sendable {
    public var loadBooks: @Sendable (_ configuration: ReaderLibraryConfiguration) throws -> [ReaderBook]
    public var loadBook: @Sendable (_ bookID: String, _ configuration: ReaderLibraryConfiguration) throws -> ReaderBook?
}

extension ReaderBookClient: TestDependencyKey {
    public static let testValue = ReaderBookClient()
}

extension DependencyValues {
    public var readerBookClient: ReaderBookClient {
        get { self[ReaderBookClient.self] }
        set { self[ReaderBookClient.self] = newValue }
    }
}
