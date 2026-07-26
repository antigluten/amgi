public import Foundation
internal import AmgiReader
internal import CryptoKit
internal import EPUBKit

/// Typed errors raised by `EPUBBookParser`.
public enum EPUBParserError: Error, Sendable, Equatable {
    /// EPUBKit's `EPUBDocument(url:)` initializer returned nil. Most
    /// commonly this means the file is not a valid EPUB archive or the
    /// container/manifest is malformed.
    case cannotOpen
    /// The EPUB parsed but its spine contained no usable items.
    case noSpine
    /// The publication metadata had no title; we refuse to create a
    /// titleless `ReaderBook` because the UI relies on it.
    case noTitle
}

/// Public, actor-isolated EPUB parser.
///
/// Wraps EPUBKit's synchronous parser in an `async` API and translates
/// the result into AmgiReader's domain types. No EPUBKit type ever
/// escapes this module — callers see only `ParsedEPUBBook`, which is
/// composed of pure-Swift / AmgiReader values.
public actor EPUBBookParser {

    public init() {}

    /// Parse the EPUB at `fileURL` into a `ParsedEPUBBook`.
    ///
    /// The `bookID` is derived as `"epub-" + sha1HexOfFileBytes` so
    /// re-importing the same file is idempotent. Chapter content URLs
    /// point at files inside EPUBKit's extracted directory
    /// (`EPUBDocument.directory`) — callers must keep that directory
    /// alive for as long as they intend to read chapters.
    public func parse(fileURL: URL) async throws -> ParsedEPUBBook {
        guard let document = EPUBDocument(url: fileURL) else {
            throw EPUBParserError.cannotOpen
        }
        guard let title = document.title, !title.isEmpty else {
            throw EPUBParserError.noTitle
        }
        guard !document.spine.items.isEmpty else {
            throw EPUBParserError.noSpine
        }

        let bookID = try Self.deriveBookID(forFileAt: fileURL)
        let language = document.metadata.language
        let author = document.metadata.creator?.name.flatMap {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
        }

        let mapped = EPUBChapterMapper.map(
            bookID: bookID,
            bookTitle: title,
            language: language,
            spine: document.spine,
            manifest: document.manifest,
            tableOfContents: document.tableOfContents,
            contentDirectory: document.contentDirectory
        )

        let coverURL = document.cover
        let coverPath = coverURL?.path

        let book = ReaderBook(
            id: bookID,
            title: title,
            author: author,
            coverImagePath: coverPath,
            language: language,
            chapters: mapped.chapters,
            pageCount: mapped.totalPageEstimate,
            source: .epub(localURL: fileURL)
        )

        return ParsedEPUBBook(
            book: book,
            chapterContentURLs: mapped.chapterContentURLs,
            coverImageURL: coverURL,
            language: language,
            pageCount: mapped.totalPageEstimate
        )
    }

    /// SHA-1 of file bytes, hex-encoded, prefixed with `"epub-"`.
    ///
    /// SHA-1 is intentional here — we need a stable content-addressable
    /// ID across imports, not a cryptographic guarantee. The 160-bit
    /// space is more than sufficient for collision avoidance across a
    /// personal EPUB library.
    static func deriveBookID(forFileAt fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let digest = Insecure.SHA1.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "epub-" + hex
    }
}
