internal import Foundation

/// On-disk shape persisted in `EPUBLibrary/index.json`. Each entry carries
/// enough chapter metadata to rebuild a `ReaderBook` without re-parsing the
/// EPUB archive on every launch.
internal struct EPUBLibraryIndexEntry: Codable, Sendable, Hashable {
    var bookID: String
    var title: String
    var author: String?
    var coverRelativePath: String?
    var language: String?
    var pageCount: Int
    var chapterIDs: [Int64]
    var chapterTitles: [String]
    var spineHrefs: [String]
    var importedAt: Date
    var originalFilename: String
}

internal struct EPUBLibraryIndexFile: Codable, Sendable {
    var version: Int
    var entries: [EPUBLibraryIndexEntry]

    init(version: Int = 1, entries: [EPUBLibraryIndexEntry] = []) {
        self.version = version
        self.entries = entries
    }
}
