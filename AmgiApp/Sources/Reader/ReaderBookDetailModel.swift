import AmgiReader
import AnkiClients
import Dependencies
import Foundation

/// Cover + per-chapter card-count loading for the book detail screen. Owns
/// the EPUB-library and card-count clients and the mapped view state so the
/// Container carries no `@Dependency`; the pure `ReaderBookDetailContent`
/// renders from the state.
@Observable
@MainActor
final class ReaderBookDetailModel {
    enum ViewState: Equatable {
        case loading
        case loaded(
            coverURL: URL?,
            cardsByChapter: [Int64: Int],
            pageRanges: [Int64: ClosedRange<Int>]
        )
    }

    var state: ViewState = .loading

    @ObservationIgnored @Dependency(\.epubLibraryClient) private var epubLibraryClient
    @ObservationIgnored @Dependency(\.readerCardCountClient) private var readerCardCountClient

    func load(book: ReaderBook) async {
        var coverURL: URL?
        if case .epub = book.source {
            coverURL = await epubLibraryClient.coverURL(book.id)
        }

        var counts: [Int64: Int] = [:]
        let bookID = book.id
        for (index, chapter) in book.chapters.enumerated() {
            let tag = "amgi::book::\(bookID)::ch::\(index)"
            let count = (try? readerCardCountClient.cardsAdded(tag)) ?? 0
            counts[chapter.id] = count
        }
        state = .loaded(
            coverURL: coverURL,
            cardsByChapter: counts,
            pageRanges: Self.pageRanges(for: book.chapters)
        )
    }

    static func pageRanges(
        for chapters: [ReaderChapter]
    ) -> [Int64: ClosedRange<Int>] {
        var out: [Int64: ClosedRange<Int>] = [:]
        var running = 0
        for chapter in chapters {
            guard let pages = chapter.pageCount, pages > 0 else { continue }
            let start = running + 1
            let end = running + pages
            out[chapter.id] = start...end
            running = end
        }
        return out
    }
}
