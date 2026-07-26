import AmgiReader
import AnkiClients
import Dependencies
import Foundation

/// Chapter-content loading for the EPUB reader. Owns the `epubLibraryClient`
/// dependency and the resolved on-disk content map so the view carries no
/// `@Dependency`; the typography `@Shared` prefs and all paging/chrome
/// state stay on the view.
@Observable
@MainActor
final class EPUBChapterReaderModel {
    var chapterContents: [Int: EPUBChapterContent] = [:]

    @ObservationIgnored @Dependency(\.epubLibraryClient) private var epubLibraryClient

    /// Pre-resolve every chapter's on-disk content URL so the
    /// `UIPageViewController` dataSource can vend adjacent VCs
    /// synchronously. The lookup is a cache hit after first call.
    func preloadChapterContents(for book: ReaderBook) async {
        var resolved: [Int: EPUBChapterContent] = [:]
        for (index, chapter) in book.chapters.enumerated() {
            guard let url = await epubLibraryClient.chapterContentURL(book.id, chapter.id) else { continue }
            resolved[index] = EPUBChapterContent(
                chapterID: chapter.id,
                contentURL: url,
                readAccessURL: url.deletingLastPathComponent()
            )
        }
        chapterContents = resolved
    }
}
