import AmgiReader
import AmgiUI
import Foundation

struct ReaderLibraryViewData: Equatable {
    var continueReading: [ContinueReadingItem]
    var allBooks: [BookCellItem]
    var hasAnkiConfig: Bool
}

struct ContinueReadingItem: Identifiable, Equatable {
    let id: String
    let title: String
    let surname: String?
    let progress: Double
    let updatedAt: Date
    let coverArt: CoverArtSource
}

struct BookCellItem: Identifiable, Equatable {
    let id: String
    let title: String
    let author: String?
    let surname: String?
    let coverArt: CoverArtSource
}

enum CoverArtSource: Equatable {
    case epub(localFileURL: URL?)
    case anki(filePath: String?)
    case none
}

enum ReaderLibraryViewDataBuilder {
    private static let continueReadingLimit = 6

    static func build(
        books: [ReaderBook],
        progressFor: (String) -> ReaderSavedProgress?,
        epubCoverURLFor: (String) -> URL?,
        searchText: String,
        sortMode: BookshelfSortMode,
        hasAnkiConfig: Bool
    ) -> ReaderLibraryViewData {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [ReaderBook] = query.isEmpty ? books : books.filter { book in
            book.title.localizedCaseInsensitiveContains(query)
                || (book.author?.localizedCaseInsensitiveContains(query) ?? false)
        }

        let progressByID: [String: ReaderSavedProgress] = Dictionary(
            uniqueKeysWithValues: filtered.compactMap { book in
                progressFor(book.id).map { (book.id, $0) }
            }
        )

        let continueReading: [ContinueReadingItem] = Array(
            filtered.compactMap { book -> ContinueReadingItem? in
                guard let p = progressByID[book.id], p.progress > 0, p.progress < 1 else {
                    return nil
                }
                return ContinueReadingItem(
                    id: book.id,
                    title: book.title,
                    surname: BookMetaFormatters.surname(from: book.author),
                    progress: p.progress,
                    updatedAt: p.updatedAt,
                    coverArt: coverArt(for: book, epubCoverURLFor: epubCoverURLFor)
                )
            }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(Self.continueReadingLimit)
        )

        let allBooks: [BookCellItem] = filtered
            .sorted { lhs, rhs in
                switch sortMode {
                case .recent:
                    let lhsDate = progressByID[lhs.id]?.updatedAt ?? .distantPast
                    let rhsDate = progressByID[rhs.id]?.updatedAt ?? .distantPast
                    if lhsDate != rhsDate { return lhsDate > rhsDate }
                case .progress:
                    let lhsProgress = progressByID[lhs.id]?.progress ?? 0
                    let rhsProgress = progressByID[rhs.id]?.progress ?? 0
                    if lhsProgress != rhsProgress { return lhsProgress > rhsProgress }
                case .title:
                    break
                }
                let cmp = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return lhs.id < rhs.id
            }
            .map { book in
                BookCellItem(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    surname: BookMetaFormatters.surname(from: book.author),
                    coverArt: coverArt(for: book, epubCoverURLFor: epubCoverURLFor)
                )
            }

        return ReaderLibraryViewData(
            continueReading: continueReading,
            allBooks: allBooks,
            hasAnkiConfig: hasAnkiConfig
        )
    }
}

private extension ReaderLibraryViewDataBuilder {
    static func coverArt(
        for book: ReaderBook,
        epubCoverURLFor: (String) -> URL?
    ) -> CoverArtSource {
        switch book.source {
        case .ankiDeck:
            return .anki(filePath: book.coverImagePath)
        case .epub:
            return .epub(localFileURL: epubCoverURLFor(book.id))
        }
    }
}
