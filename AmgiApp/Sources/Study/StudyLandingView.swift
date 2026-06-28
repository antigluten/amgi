// AmgiApp/Sources/Study/StudyLandingView.swift
import SwiftUI
import AmgiUI
import AmgiReader
import AnkiKit

/// Study tab container. Holds a `StudyLandingModel` that loads the deck tree
/// + reader books and maps to `StudyLandingContent.State`; forwards
/// navigation callbacks to the parent (`ContentView`).
struct StudyLandingView: View {
    /// Called when the user taps a deck row or "Begin Session".
    /// Sets `pendingReviewDeckId` on ContentView to trigger the
    /// existing fullscreen cover.
    let onSelectDeck: (DeckID) -> Void

    @State private var model = StudyLandingModel()
    @State private var loadTask: Task<Void, Never>?

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
        .task {
            loadTask = Task { await model.load() }
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private func beginSession() {
        // Pick the first deck with due cards (sorted desc by totalDue already).
        guard case .loaded(_, let decks, _) = model.contentState,
              let first = decks.first else { return }
        onSelectDeck(DeckID(first.id))
    }
}
