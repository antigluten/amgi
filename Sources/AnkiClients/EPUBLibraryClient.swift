public import AmgiReader
import AmgiReaderEPUB
public import Dependencies
public import Foundation
import DependenciesMacros

@DependencyClient
public struct EPUBLibraryClient: Sendable {
    public var importEPUB: @Sendable (_ sourceURL: URL) async throws -> ReaderBook
    public var listBooks: @Sendable () async -> [ReaderBook] = { [] }
    public var deleteBook: @Sendable (_ bookID: String) async throws -> Void
    public var chapterContentURL: @Sendable (_ bookID: String, _ chapterID: Int64) async -> URL?
    public var coverURL: @Sendable (_ bookID: String) async -> URL?
}

extension EPUBLibraryClient: TestDependencyKey {
    public static let testValue = EPUBLibraryClient()
}

extension DependencyValues {
    public var epubLibraryClient: EPUBLibraryClient {
        get { self[EPUBLibraryClient.self] }
        set { self[EPUBLibraryClient.self] = newValue }
    }
}

extension EPUBLibraryClient: DependencyKey {
    public static let liveValue: Self = {
        let store = SharedEPUBLibraryStore.store
        return Self(
            importEPUB: { url in try await store.importEPUB(from: url) },
            listBooks: { await store.books() },
            deleteBook: { bookID in try await store.delete(bookID: bookID) },
            chapterContentURL: { bookID, chapterID in
                await store.contentURL(bookID: bookID, chapterID: chapterID)
            },
            coverURL: { bookID in await store.coverURL(bookID: bookID) }
        )
    }()
}

private enum SharedEPUBLibraryStore {
    static let store = EPUBLibraryStore()
}
