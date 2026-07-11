public import Foundation
public import AmgiReader

/// Actor-owned on-disk library of imported EPUB books.
///
/// Layout under `rootDirectory`:
/// ```
/// index.json
/// {bookID}/
///   original.epub
///   extracted/ ...        (created by EPUBKit during parse)
///   cover.{ext}
/// ```
///
/// `books()` rebuilds `ReaderBook` values from the index plus the on-disk
/// extracted chapter URLs, without re-running the full EPUB parse each
/// time. Parsed books are cached in-memory between calls.
public actor EPUBLibraryStore {

    public enum StoreError: Error, Sendable {
        case bookNotFound
        case missingExtractedDirectory
        case importFailed(underlying: String)
    }

    private let rootDirectory: URL
    private var index: EPUBLibraryIndexFile
    private var bookCache: [String: ReaderBook] = [:]
    private var chapterURLCache: [String: [Int64: URL]] = [:]
    private let parser = EPUBBookParser()

    public init(rootDirectory: URL? = nil) {
        let root: URL
        if let rootDirectory {
            root = rootDirectory
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            root = support.appendingPathComponent("Amgi/EPUBLibrary", isDirectory: true)
        }
        self.rootDirectory = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        self.index = Self.readIndex(at: root) ?? EPUBLibraryIndexFile()
    }

    // MARK: - Public API

    public func importEPUB(from sourceURL: URL) async throws -> ReaderBook {
        let needsScope = sourceURL.isFileURL && sourceURL.startAccessingSecurityScopedResource()
        defer { if needsScope { sourceURL.stopAccessingSecurityScopedResource() } }

        let bookID: String
        do {
            bookID = try EPUBBookParser.deriveBookID(forFileAt: sourceURL)
        } catch {
            throw StoreError.importFailed(underlying: error.localizedDescription)
        }

        let bookDir = rootDirectory.appendingPathComponent(bookID, isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)

        let copiedEPUB = bookDir.appendingPathComponent("original.epub")
        if FileManager.default.fileExists(atPath: copiedEPUB.path) {
            try? FileManager.default.removeItem(at: copiedEPUB)
        }
        try FileManager.default.copyItem(at: sourceURL, to: copiedEPUB)

        let parsed: ParsedEPUBBook
        do {
            parsed = try await parser.parse(fileURL: copiedEPUB)
        } catch {
            throw StoreError.importFailed(underlying: String(describing: error))
        }

        var coverRelative: String?
        if let coverURL = parsed.coverImageURL,
           FileManager.default.fileExists(atPath: coverURL.path) {
            let ext = coverURL.pathExtension.isEmpty ? "img" : coverURL.pathExtension
            let dest = bookDir.appendingPathComponent("cover.\(ext)")
            if FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.removeItem(at: dest)
            }
            do {
                try FileManager.default.copyItem(at: coverURL, to: dest)
                coverRelative = "\(bookID)/cover.\(ext)"
            } catch {
                coverRelative = nil
            }
        }

        let entry = EPUBLibraryIndexEntry(
            bookID: bookID,
            title: parsed.book.title,
            author: parsed.book.author,
            coverRelativePath: coverRelative,
            language: parsed.language,
            pageCount: parsed.pageCount
        )

        if let existing = index.entries.firstIndex(where: { $0.bookID == bookID }) {
            index.entries[existing] = entry
        } else {
            index.entries.append(entry)
        }
        try writeIndex()

        bookCache[bookID] = parsed.book
        chapterURLCache[bookID] = parsed.chapterContentURLs
        return parsed.book
    }

    public func books() async -> [ReaderBook] {
        var out: [ReaderBook] = []
        for entry in index.entries {
            if let cached = bookCache[entry.bookID] {
                out.append(cached)
                continue
            }
            if let rebuilt = await rebuildBook(from: entry) {
                bookCache[entry.bookID] = rebuilt
                out.append(rebuilt)
            }
        }
        return out
    }

    public func delete(bookID: String) async throws {
        guard let idx = index.entries.firstIndex(where: { $0.bookID == bookID }) else {
            throw StoreError.bookNotFound
        }
        let bookDir = rootDirectory.appendingPathComponent(bookID, isDirectory: true)
        try? FileManager.default.removeItem(at: bookDir)
        index.entries.remove(at: idx)
        bookCache.removeValue(forKey: bookID)
        chapterURLCache.removeValue(forKey: bookID)
        try writeIndex()
    }

    public func contentURL(bookID: String, chapterID: Int64) async -> URL? {
        if let map = chapterURLCache[bookID], let url = map[chapterID] {
            return url
        }
        guard let entry = index.entries.first(where: { $0.bookID == bookID }) else { return nil }
        _ = await rebuildBook(from: entry)
        return chapterURLCache[bookID]?[chapterID]
    }

    public func coverURL(bookID: String) async -> URL? {
        guard let entry = index.entries.first(where: { $0.bookID == bookID }),
              let rel = entry.coverRelativePath else { return nil }
        let url = rootDirectory.appendingPathComponent(rel)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Internals

    /// Re-parse the on-disk EPUB to recover chapter HTML URLs. We keep
    /// `original.epub` so EPUBKit can re-extract on demand; the resulting
    /// extracted directory is owned by EPUBKit's temp space, which is fine
    /// for read-only access during a session.
    private func rebuildBook(from entry: EPUBLibraryIndexEntry) async -> ReaderBook? {
        let epubURL = rootDirectory
            .appendingPathComponent(entry.bookID, isDirectory: true)
            .appendingPathComponent("original.epub")
        guard FileManager.default.fileExists(atPath: epubURL.path) else { return nil }
        do {
            let parsed = try await parser.parse(fileURL: epubURL)
            chapterURLCache[entry.bookID] = parsed.chapterContentURLs
            return parsed.book
        } catch {
            return nil
        }
    }

    private func writeIndex() throws {
        let url = rootDirectory.appendingPathComponent("index.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(index)
        try data.write(to: url, options: .atomic)
    }

    private static func readIndex(at root: URL) -> EPUBLibraryIndexFile? {
        let url = root.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(EPUBLibraryIndexFile.self, from: data)
    }
}
