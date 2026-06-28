import AmgiReader
import AnkiClients
import Dependencies
import Sharing
import SwiftUI

// MARK: - Sort mode

enum BookshelfSortMode: String, CaseIterable, Identifiable {
    case recent
    case title
    case progress

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recent:   "Recently Read"
        case .title:    "Title"
        case .progress: "Progress"
        }
    }
}

// MARK: - Library view

struct ReaderLibraryView: View {
    @Dependency(\.readerBookClient) var readerBookClient

    @Shared(.appStorage(ReaderPreferenceKey.deckName)) private var deckName: String = ""
    @Shared(.appStorage(ReaderPreferences.Keys.bookshelfColumns)) private var bookshelfColumns: Int = 2
    @Shared(.appStorage(ReaderPreferences.Keys.bookshelfSortMode)) private var sortModeRaw: String = BookshelfSortMode.recent.rawValue

    @State private var books: [ReaderBook] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var showConfiguration = false
    @State private var searchText: String = ""

    private let progress = ReaderProgressCoordinator()

    private var sortMode: BookshelfSortMode {
        BookshelfSortMode(rawValue: sortModeRaw) ?? .recent
    }

    private var clampedColumns: Int {
        min(max(bookshelfColumns, 1), 4)
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12, alignment: .top),
            count: clampedColumns
        )
    }

    private var filteredBooks: [ReaderBook] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return books }
        return books.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    private var sortedBooks: [ReaderBook] {
        filteredBooks.sorted { lhs, rhs in
            switch sortMode {
            case .recent:
                let lhsDate = progress.resolved(bookID: lhs.id)?.updatedAt ?? .distantPast
                let rhsDate = progress.resolved(bookID: rhs.id)?.updatedAt ?? .distantPast
                if lhsDate != rhsDate { return lhsDate > rhsDate }
            case .progress:
                let lhsPct = progress.resolved(bookID: lhs.id)?.progress ?? 0
                let rhsPct = progress.resolved(bookID: rhs.id)?.progress ?? 0
                if lhsPct != rhsPct { return lhsPct > rhsPct }
            case .title:
                break
            }
            let cmp = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if cmp != .orderedSame { return cmp == .orderedAscending }
            return lhs.id < rhs.id
        }
    }

    var body: some View {
        Group {
            if let configuration = ReaderConfigurationLoader.loadConfiguration() {
                bookshelf(configuration: configuration)
            } else {
                emptyState
            }
        }
        .navigationTitle("Reader")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 4) {
                    Button {
                        bookshelfColumns = max(clampedColumns - 1, 1)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(clampedColumns <= 1)

                    Text("\(clampedColumns)")
                        .monospacedDigit()
                        .frame(minWidth: 16)

                    Button {
                        bookshelfColumns = min(clampedColumns + 1, 4)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(clampedColumns >= 4)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(BookshelfSortMode.allCases) { mode in
                        Button {
                            sortModeRaw = mode.rawValue
                        } label: {
                            if sortMode == mode {
                                Label(mode.label, systemImage: "checkmark")
                            } else {
                                Text(mode.label)
                            }
                        }
                    }
                    Divider()
                    Button {
                        showConfiguration = true
                    } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showConfiguration) {
            NavigationStack {
                ReaderConfigurationView {
                    showConfiguration = false
                    Task { await reload() }
                }
            }
        }
        .task { await reload() }
        .onChange(of: deckName) { _, _ in
            Task { await reload() }
        }
    }

    // MARK: - Bookshelf

    @ViewBuilder
    private func bookshelf(configuration: AmgiReader.ReaderLibraryConfiguration) -> some View {
        if isLoading && books.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let loadError {
            ContentUnavailableView {
                Label("Couldn't load books", systemImage: "exclamationmark.triangle")
            } description: {
                Text(loadError)
            } actions: {
                Button("Retry") { Task { await reload() } }
            }
        } else if books.isEmpty {
            ContentUnavailableView(
                "No books in \"\(configuration.deckName)\"",
                systemImage: "book.closed",
                description: Text("Add notes to that deck — each note becomes a chapter, and notes sharing a Book ID collapse into a single book.")
            )
        } else {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(sortedBooks) { book in
                        NavigationLink {
                            ChapterListView(book: book, progress: progress)
                        } label: {
                            BookGridCell(book: book, savedProgress: progress.resolved(bookID: book.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
            .searchable(text: $searchText, prompt: "Search books")
            .refreshable { await reload() }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Reader not configured", systemImage: "books.vertical")
        } description: {
            Text("Pick a deck and map your notetype fields to start reading books from your collection.")
        } actions: {
            Button("Set Up Reader") { showConfiguration = true }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Data

    private func reload() async {
        guard let configuration = ReaderConfigurationLoader.loadConfiguration() else {
            books = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            books = try readerBookClient.loadBooks(configuration)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
            books = []
        }
    }
}

// MARK: - Grid cell

private struct BookGridCell: View {
    let book: ReaderBook
    let savedProgress: ReaderSavedProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            cover
                .aspectRatio(100 / 136, contentMode: .fit)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(book.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundStyle(.primary)

            if let savedProgress {
                ProgressView(value: savedProgress.progress)
                    .tint(.accentColor)
            }
        }
    }

    @ViewBuilder
    private var cover: some View {
        ReaderCoverImage(path: book.coverImagePath) {
            coverPlaceholder
        }
    }

    private var coverPlaceholder: some View {
        Image(systemName: "book.closed")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - List row (kept for potential future use / reference)

private struct BookRow: View {
    let book: ReaderBook
    let savedProgress: ReaderSavedProgress?

    var body: some View {
        HStack(spacing: 12) {
            cover
                .frame(width: 44, height: 60)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title).font(.headline)
                Text("\(book.chapters.count) chapter\(book.chapters.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let savedProgress, let chapter = book.chapters.first(where: { $0.id == savedProgress.chapterID }) {
                    Text("\(chapter.title) · \(Int(savedProgress.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var cover: some View {
        ReaderCoverImage(path: book.coverImagePath) {
            Image(systemName: "book.closed").foregroundStyle(.secondary)
        }
    }
}
