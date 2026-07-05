import AmgiReader
import AnkiClients
import Dependencies
import Foundation

/// Data state + load/import logic for the reader Library screen. Mirrors
/// `DeckListModel`: the View owns navigation, search, sheets, and the
/// toolbar, while the model owns the EPUB/Anki book I/O, cover resolution,
/// and the engine → `ReaderLibraryContent.State` assembly so that assembly
/// is testable in isolation and the View stays thin.
@Observable
@MainActor
final class ReaderLibraryModel {
    var state: ReaderLibraryContent.State = .loading
    var importError: String?

    private(set) var books: [ReaderBook] = []
    private var bookIndex: [String: ReaderBook] = [:]
    private var epubCoverURLs: [String: URL] = [:]

    @ObservationIgnored @Dependency(\.readerBookClient) private var readerBookClient
    @ObservationIgnored @Dependency(\.epubLibraryClient) private var epubLibraryClient
    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    /// Shared with `ReaderLibraryContent` so the list and the loader resolve
    /// saved progress through the same store.
    let progress: ReaderProgressCoordinator

    init(progress: ReaderProgressCoordinator = ReaderProgressCoordinator()) {
        self.progress = progress
    }

    func book(for id: String) -> ReaderBook? { bookIndex[id] }

    var hasAnkiConfiguration: Bool {
        ReaderConfigurationLoader.loadConfiguration() != nil
    }

    func startReload(searchText: String, sortMode: BookshelfSortMode) {
        reloadTask?.cancel()
        reloadTask = Task { await reload(searchText: searchText, sortMode: sortMode) }
    }

    func reload(searchText: String, sortMode: BookshelfSortMode) async {
        if books.isEmpty { state = .loading }

        async let epubBooks: [ReaderBook] = epubLibraryClient.listBooks()

        var ankiBooks: [ReaderBook] = []
        var firstError: String?
        if let configuration = ReaderConfigurationLoader.loadConfiguration() {
            do {
                ankiBooks = try await readerBookClient.loadBooks(configuration)
            } catch {
                firstError = error.localizedDescription
            }
        }

        let resolvedEPUBs = await epubBooks
        if Task.isCancelled { return }
        let merged = ankiBooks + resolvedEPUBs
        books = merged
        bookIndex = Dictionary(merged.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let epubIDs = merged.compactMap { book -> String? in
            if case .epub = book.source { return book.id }
            return nil
        }
        var resolved: [String: URL] = [:]
        let client = epubLibraryClient
        await withTaskGroup(of: (String, URL?).self) { group in
            for id in epubIDs {
                group.addTask {
                    let url = await client.coverURL(id)
                    return (id, url)
                }
            }
            for await (id, url) in group {
                if let url { resolved[id] = url }
            }
        }
        if Task.isCancelled { return }
        epubCoverURLs = resolved

        if merged.isEmpty {
            if let firstError {
                state = .error(firstError)
            } else if hasAnkiConfiguration {
                state = .empty(.noBooksConfigured)
            } else {
                state = .empty(.noBooksAndNoConfig)
            }
            return
        }

        rebuildViewData(searchText: searchText, sortMode: sortMode)
    }

    func rebuildViewData(searchText: String, sortMode: BookshelfSortMode) {
        guard !books.isEmpty else { return }
        let coverURLs = epubCoverURLs
        let data = ReaderLibraryViewDataBuilder.build(
            books: books,
            progressFor: { [progress] in progress.resolved(bookID: $0) },
            epubCoverURLFor: { coverURLs[$0] },
            searchText: searchText,
            sortMode: sortMode,
            hasAnkiConfig: hasAnkiConfiguration
        )
        state = .loaded(data)
    }

    func importEPUBs(_ urls: [URL], searchText: String, sortMode: BookshelfSortMode) async {
        var succeeded = 0
        for url in urls {
            do {
                _ = try await epubLibraryClient.importEPUB(url)
                succeeded += 1
            } catch {
                importError = error.localizedDescription
            }
        }
        if succeeded > 0 {
            startReload(searchText: searchText, sortMode: sortMode)
        }
    }
}
