public import Foundation
internal import CryptoKit

public struct ReaderFieldMapping: Sendable, Hashable {
    public var bookIDField: String
    public var bookTitleField: String
    public var bookCoverField: String?
    public var chapterTitleField: String
    public var chapterOrderField: String
    public var contentField: String
    public var languageField: String?

    public init(
        bookIDField: String,
        bookTitleField: String,
        bookCoverField: String? = nil,
        chapterTitleField: String,
        chapterOrderField: String,
        contentField: String,
        languageField: String? = nil
    ) {
        self.bookIDField = bookIDField
        self.bookTitleField = bookTitleField
        self.bookCoverField = bookCoverField
        self.chapterTitleField = chapterTitleField
        self.chapterOrderField = chapterOrderField
        self.contentField = contentField
        self.languageField = languageField
    }
}

public struct ReaderLibraryConfiguration: Sendable, Hashable {
    public var deckName: String
    public var notetypeID: Int64?
    public var fieldMapping: ReaderFieldMapping

    public init(deckName: String, notetypeID: Int64? = nil, fieldMapping: ReaderFieldMapping) {
        self.deckName = deckName
        self.notetypeID = notetypeID
        self.fieldMapping = fieldMapping
    }
}

public struct ReaderChapter: Sendable, Hashable, Identifiable {
    public let id: Int64
    public var bookID: String
    public var bookTitle: String
    public var title: String
    public var order: String?
    public var content: String
    public var language: String?
    /// Per-chapter page estimate from EPUB parsing. Nil for Anki-deck chapters.
    public var pageCount: Int?

    public init(
        id: Int64,
        bookID: String,
        bookTitle: String,
        title: String,
        order: String? = nil,
        content: String,
        language: String? = nil,
        pageCount: Int? = nil
    ) {
        self.id = id
        self.bookID = bookID
        self.bookTitle = bookTitle
        self.title = title
        self.order = order
        self.content = content
        self.language = language
        self.pageCount = pageCount
    }
}

/// Where a `ReaderBook` was sourced from. Determines which subsystem owns
/// chapter content lookup at read time.
///
/// - `.ankiDeck`: chapters resolve through the existing Anki-note pipeline
///   (`ReaderBookClient` / `ReaderFieldMapping`). The default for legacy
///   call-sites.
/// - `.epub(localURL:)`: chapters resolve through `AmgiReaderEPUB`'s
///   library store. `localURL` points at the imported `.epub` file on
///   disk; chapter HTML lives alongside it in an extracted directory.
public enum ReaderBookSource: Sendable, Hashable {
    case ankiDeck
    case epub(localURL: URL)
}

public struct ReaderBook: Sendable, Hashable, Identifiable {
    public let id: String
    public var title: String
    public var author: String?
    public var coverImagePath: String?
    public var language: String?
    public var chapters: [ReaderChapter]
    /// Best-effort total page estimate. EPUB books populate this from a
    /// word-count heuristic at parse time; Anki-deck books leave it nil.
    public var pageCount: Int?
    public var source: ReaderBookSource

    public init(
        id: String,
        title: String,
        author: String? = nil,
        coverImagePath: String? = nil,
        language: String? = nil,
        chapters: [ReaderChapter],
        pageCount: Int? = nil,
        source: ReaderBookSource = .ankiDeck
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.coverImagePath = coverImagePath
        self.language = language
        self.chapters = chapters
        self.pageCount = pageCount
        self.source = source
    }
}

extension ReaderChapter {
    /// Deterministic `Int64` chapter ID for EPUB-sourced chapters.
    ///
    /// Anki-sourced chapters already have stable note IDs we can fit in
    /// `ReaderChapter.id`. EPUB spine items don't, so we synthesise an ID
    /// by hashing the composite key `bookID|spineIndex|spineHref-prefix`
    /// with SHA-256 and reading the leading 8 bytes big-endian as a
    /// non-negative `Int64`. The 64-bit collision space (with the sign
    /// bit masked) is enormous relative to typical book sizes; callers
    /// should still assert uniqueness within a single book at parse time.
    public static func epubChapterID(
        bookID: String,
        spineIndex: Int,
        spineHref: String
    ) -> Int64 {
        let hrefPrefix = String(spineHref.prefix(64))
        let composite = "\(bookID)|\(spineIndex)|\(hrefPrefix)"
        let digest = SHA256.hash(data: Data(composite.utf8))
        var value: UInt64 = 0
        for byte in digest.prefix(8) {
            value = (value << 8) | UInt64(byte)
        }
        // Mask the sign bit so callers always see a non-negative Int64.
        let masked = value & 0x7FFF_FFFF_FFFF_FFFF
        return Int64(bitPattern: masked)
    }
}
