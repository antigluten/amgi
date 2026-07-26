import AmgiReader
import SwiftUI

struct ReaderLibraryContent: View {
    enum State: Equatable {
        case loading
        case empty(EmptyReason)
        case loaded(ReaderLibraryViewData)
        case error(String)
    }

    enum EmptyReason: Equatable {
        case noBooksAndNoConfig
        case noBooksConfigured
    }

    let state: State
    let bookForId: (String) -> ReaderBook?
    let progress: ReaderProgressCoordinator
    let onImport: () -> Void
    let onConfigure: () -> Void
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty(let reason):
            empty(reason)

        case .loaded(let data):
            loaded(data)

        case .error(let message):
            ContentUnavailableView {
                Label("Couldn't load books", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry", action: onRetry)
            }
        }
    }

}

private extension ReaderLibraryContent {
    func empty(_ reason: EmptyReason) -> some View {
        ContentUnavailableView {
            Label("No books yet", systemImage: "books.vertical")
        } description: {
            switch reason {
            case .noBooksAndNoConfig:
                Text("Import an EPUB or configure a deck of notes to start reading.")
            case .noBooksConfigured:
                Text("Your configured deck doesn't have any books yet. Import an EPUB or reconfigure your reader source.")
            }
        } actions: {
            Button(action: onImport) { Label("Import EPUB", systemImage: "plus") }
                .buttonStyle(.borderedProminent)
            Button(reason == .noBooksConfigured ? "Reconfigure Reader" : "Set Up Anki Library",
                   action: onConfigure)
        }
    }

    @ViewBuilder
    func loaded(_ data: ReaderLibraryViewData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ContinueReadingSection(items: data.continueReading, bookForId: bookForId, progress: progress)
                AllBooksSection(items: data.allBooks, bookForId: bookForId, progress: progress)
                ImportBookCTA(action: onImport)
                Color.clear.frame(height: 8)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Loaded") {
    let books: [ReaderBook] = [
        .sample,
        ReaderBook(id: "b2", title: "Le Petit Prince", author: "Antoine de Saint-Exupéry", chapters: []),
        ReaderBook(id: "b3", title: "어린 왕자", author: "생텍쥐페리", chapters: []),
    ]
    // Run the real builder over sample books so the grid mirrors production.
    let data = ReaderLibraryViewDataBuilder.build(
        books: books,
        progressFor: { _ in nil },
        epubCoverURLFor: { _ in nil },
        searchText: "",
        sortMode: .title,
        hasAnkiConfig: true
    )
    return NavigationStack {
        ReaderLibraryContent(
            state: .loaded(data),
            bookForId: { id in books.first { $0.id == id } },
            progress: ReaderProgressCoordinator(),
            onImport: {},
            onConfigure: {},
            onRetry: {}
        )
        .navigationTitle("Library")
    }
}

#Preview("Empty") {
    NavigationStack {
        ReaderLibraryContent(
            state: .empty(.noBooksAndNoConfig),
            bookForId: { _ in nil },
            progress: ReaderProgressCoordinator(),
            onImport: {},
            onConfigure: {},
            onRetry: {}
        )
        .navigationTitle("Library")
    }
}
#endif
