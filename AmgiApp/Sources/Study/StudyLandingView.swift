// AmgiApp/Sources/Study/StudyLandingView.swift
import SwiftUI
import AmgiUI
import AmgiReader
import AnkiKit
import Dependencies

/// Study tab container. Holds a `StudyLandingModel` that loads the deck tree
/// + reader books and maps to `StudyLandingContent.State`; forwards
/// navigation callbacks to the parent (`ContentView`).
struct StudyLandingView: View {
    /// Called when the user taps a deck row or "Begin Session".
    /// Sets `pendingReviewDeckId` on ContentView to trigger the
    /// existing fullscreen cover.
    let onSelectDeck: (DeckID) -> Void

    @Dependency(\.collectionStore) private var store
    @State private var model = StudyLandingModel()

    var body: some View {
        StudyLandingContent(
            state: model.contentState,
            onBeginSession: beginSession,
            onSelectDeck: { id in onSelectDeck(DeckID(id)) },
            onSelectBook: { bookID in model.selectBook(bookID) },
            onRefresh: { await model.load() }
        )
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $model.selectedBook) { book in
            NavigationStack {
                ChapterListView(book: book, progress: model.progressCoordinator)
            }
        }
        // Keyed on the store's generation: any Invalidation re-runs the
        // load; `.task` cancels itself on disappear.
        .task(id: store.generation) { await model.load() }
    }

    private func beginSession() {
        // Pick the first deck with due cards (sorted desc by totalDue already).
        guard case .loaded(_, let decks, _) = model.contentState,
              let first = decks.first else { return }
        onSelectDeck(DeckID(first.id))
    }
}
