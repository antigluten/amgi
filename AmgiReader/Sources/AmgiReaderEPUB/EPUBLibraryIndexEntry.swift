internal import Foundation

/// On-disk shape persisted in `EPUBLibrary/index.json`.
internal struct EPUBLibraryIndexEntry: Codable, Sendable, Hashable {
    var bookID: String
    var title: String
    var author: String?
    var coverRelativePath: String?
    var language: String?
    var pageCount: Int
}

internal struct EPUBLibraryIndexFile: Codable, Sendable {
    var version: Int
    var entries: [EPUBLibraryIndexEntry]

    init(version: Int = 1, entries: [EPUBLibraryIndexEntry] = []) {
        self.version = version
        self.entries = entries
    }
}
