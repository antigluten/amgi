internal import Foundation
internal import AmgiReader
internal import EPUBKit

/// Internal helpers that translate EPUBKit's spine / manifest / TOC into
/// AmgiReader's domain `ReaderChapter` values and a side-channel URL map.
///
/// EPUBKit types are intentionally kept off the public API of this
/// module — only this file (and the parser actor) touches them.
enum EPUBChapterMapper {

    /// Result of mapping a single EPUB document into the reader's domain.
    struct MappedChapters {
        var chapters: [ReaderChapter]
        var chapterContentURLs: [Int64: URL]
        /// Sum of per-chapter page estimates (word-count / 250, ceiling).
        var totalPageEstimate: Int
    }

    /// Build the chapter list for a parsed EPUB.
    ///
    /// - Parameters:
    ///   - bookID: synthetic stable book identifier (e.g. `"epub-<sha1>"`).
    ///   - bookTitle: resolved title for embedding in each chapter row.
    ///   - language: optional BCP-47 language tag for the publication.
    ///   - spine: EPUB spine in reading order.
    ///   - manifest: EPUB manifest (used to resolve href + media type).
    ///   - tableOfContents: top-level NCX node (used for chapter titles).
    ///   - contentDirectory: directory containing the OPF, used as the
    ///     base for resolving relative spine hrefs.
    static func map(
        bookID: String,
        bookTitle: String,
        language: String?,
        spine: EPUBSpine,
        manifest: EPUBManifest,
        tableOfContents: EPUBTableOfContents,
        contentDirectory: URL
    ) -> MappedChapters {
        let tocByHref = flattenTOC(tableOfContents)

        var chapters: [ReaderChapter] = []
        var urls: [Int64: URL] = [:]
        var totalPages = 0
        var seenIDs: Set<Int64> = []

        for (index, spineItem) in spine.items.enumerated() {
            guard let manifestItem = manifest.items[spineItem.idref] else {
                continue
            }
            let href = manifestItem.path
            let absoluteURL = contentDirectory.appendingPathComponent(href)

            let chapterID = ReaderChapter.epubChapterID(
                bookID: bookID,
                spineIndex: index,
                spineHref: href
            )
            // Defensive: skip on the vanishingly rare hash collision.
            // Caller can compare `chapters.count` to `spine.items.count`
            // if it cares.
            guard seenIDs.insert(chapterID).inserted else { continue }

            // Prefer NCX-derived label, fall back to the file's basename
            // (sans extension) so the user always sees something.
            let hrefKey = normalizedHrefKey(href)
            let title = tocByHref[hrefKey]
                ?? (absoluteURL.deletingPathExtension().lastPathComponent)

            let html = (try? String(contentsOf: absoluteURL, encoding: .utf8)) ?? ""
            let pages = estimatePages(forHTML: html)
            totalPages += pages

            let chapter = ReaderChapter(
                id: chapterID,
                bookID: bookID,
                bookTitle: bookTitle,
                title: title,
                order: String(format: "%05d", index),
                content: html,
                language: language,
                pageCount: pages
            )
            chapters.append(chapter)
            urls[chapterID] = absoluteURL
        }

        return MappedChapters(
            chapters: chapters,
            chapterContentURLs: urls,
            totalPageEstimate: max(totalPages, 1)
        )
    }

    /// Strip HTML tags via the simple `<[^>]+>` regex, split on
    /// whitespace, divide by 250 words/page (ceiling). 250 is the
    /// canonical reading-system word-per-page figure used by Apple Books
    /// and several reference implementations.
    static func estimatePages(forHTML html: String) -> Int {
        let stripped = html.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        let words = stripped.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let count = words.count
        guard count > 0 else { return 1 }
        return (count + 249) / 250
    }

    /// Flatten the NCX tree into a `[href-without-fragment: label]`
    /// dictionary so we can look up chapter titles by file path.
    private static func flattenTOC(
        _ root: EPUBTableOfContents
    ) -> [String: String] {
        var out: [String: String] = [:]
        var stack: [EPUBTableOfContents] = [root]
        while let node = stack.popLast() {
            if let item = node.item {
                let key = normalizedHrefKey(item)
                // First write wins — top-level chapter labels take
                // precedence over deeper sub-section labels for the
                // same file.
                if out[key] == nil {
                    out[key] = node.label
                }
            }
            if let subTable = node.subTable {
                stack.append(contentsOf: subTable)
            }
        }
        return out
    }

    /// Drop fragment identifier and collapse to a comparable form.
    private static func normalizedHrefKey(_ href: String) -> String {
        if let hashIdx = href.firstIndex(of: "#") {
            return String(href[..<hashIdx])
        }
        return href
    }
}
