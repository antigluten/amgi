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

    public init(
        id: Int64,
        bookID: String,
        bookTitle: String,
        title: String,
        order: String? = nil,
        content: String,
        language: String? = nil
    ) {
        self.id = id
        self.bookID = bookID
        self.bookTitle = bookTitle
        self.title = title
        self.order = order
        self.content = content
        self.language = language
    }
}

public struct ReaderBook: Sendable, Hashable, Identifiable {
    public let id: String
    public var title: String
    public var coverImagePath: String?
    public var language: String?
    public var chapters: [ReaderChapter]

    public init(
        id: String,
        title: String,
        coverImagePath: String? = nil,
        language: String? = nil,
        chapters: [ReaderChapter]
    ) {
        self.id = id
        self.title = title
        self.coverImagePath = coverImagePath
        self.language = language
        self.chapters = chapters
    }
}
