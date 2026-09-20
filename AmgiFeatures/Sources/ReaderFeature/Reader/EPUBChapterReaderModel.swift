//
//  EPUBChapterReaderModel.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 23.06.2026.
//

import Reader
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
        var resolved = [Int: EPUBChapterContent](minimumCapacity: book.chapters.count)
        // Scope read access to the book's content root, not the chapter
        // file's own parent. The standard EPUB layout puts chapters in
        // OEBPS/Text/ with stylesheets in OEBPS/Styles/ and images in
        // OEBPS/Images/, so the narrower scope left chapters unstyled and
        // imageless.
        let epubLibraryClient = epubLibraryClient
        let contentRoot = await epubLibraryClient.contentRootURL(book.id)
        for (index, chapter) in book.chapters.enumerated() {
            guard let url = await epubLibraryClient.chapterContentURL(book.id, chapter.id) else { continue }
            resolved[index] = EPUBChapterContent(
                chapterID: chapter.id,
                contentURL: url,
                readAccessURL: contentRoot ?? url.deletingLastPathComponent()
            )
        }
        chapterContents = resolved
    }
}
