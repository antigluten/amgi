public import Foundation
public import AmgiReader

/// Output of `EPUBBookParser.parse(fileURL:)`.
///
/// Carries the parsed `ReaderBook` plus the side-channel data the reader
/// UI needs but that doesn't belong on the domain type itself: a map from
/// chapter ID to the on-disk URL of the chapter's HTML, the resolved
/// cover image (if any), the publication language, and the word-count
/// page estimate. The map keys match `ReaderChapter.id` values inside
/// `book.chapters`.
public struct ParsedEPUBBook: Sendable {
    public var book: ReaderBook
    public var chapterContentURLs: [Int64: URL]
    public var coverImageURL: URL?
    public var language: String?
    public var pageCount: Int

    public init(
        book: ReaderBook,
        chapterContentURLs: [Int64: URL],
        coverImageURL: URL?,
        language: String?,
        pageCount: Int
    ) {
        self.book = book
        self.chapterContentURLs = chapterContentURLs
        self.coverImageURL = coverImageURL
        self.language = language
        self.pageCount = pageCount
    }
}
