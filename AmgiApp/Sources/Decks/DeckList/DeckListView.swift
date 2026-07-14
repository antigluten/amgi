// AmgiApp/Sources/Decks/DeckList/DeckListView.swift
import SwiftUI
import AmgiTheme
import AmgiUI
import AnkiKit
import AnkiClients
import Dependencies

/// Library container: owns navigation, sheets, and the toolbar, and drives
/// a `DeckListModel` for load/refresh + deck mutations. Rendering is
/// delegated to `LibraryListContent` (AmgiUI); data assembly lives in the
/// model. The View is intentionally thin — presentation wiring only.
struct DeckListView: View {
    @Dependency(\.collectionStore) private var store
    @State private var model: DeckListModel
    @State private var showCreateSheet = false
    @State private var renameTarget: DeckRowViewData?
    @State private var pendingDeck: DeckInfo?

    init(model: DeckListModel = DeckListModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        LibraryListContent(
            state: model.state,
            onRefresh: { await model.load() },
            onStartReview: { pendingDeck = model.firstReviewableDeck() },
            onTapDeck: { row in pendingDeck = row.asDeckInfo },
            onDeleteDeck: { rawID in await model.delete(DeckID(rawID)) },
            onRenameDeck: { row in renameTarget = row }
        )
        .navigationTitle("Library")
        .navigationDestination(item: $pendingDeck) { deck in
            DeckDetailView(deck: deck)
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showCreateSheet) {
            CreateDeckSheet {
                showCreateSheet = false
            }
        }
        .sheet(item: $renameTarget) { row in
            RenameDeckSheet(deckId: DeckID(row.id), currentName: row.fullName) {
                renameTarget = nil
            }
        }
        // Keyed on the store's generation: any Invalidation (deck mutation,
        // sync, import, review-end) re-runs the load; `.task` still cancels
        // on disappear.
        .task(id: store.generation) { await model.load() }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            ProfilePickerMenu()
        }
        ToolbarItem(placement: .topBarTrailing) {
            // Browse entry — TODO: wire navigation when Browse is reachable from Library.
            Button("Browse", systemImage: "square.stack.3d.up") {
                // No-op for now; existing surface kept to match the design's two pill buttons.
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("New Deck", systemImage: "plus") {
                showCreateSheet = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    // Preview clients keep refresh/delete working in the live canvas;
    // the seeded `.loaded` state makes the first snapshot deterministic
    // instead of racing the async `.task` load.
    let model = withDependencies {
        $0.deckClient = .previewValue
        $0.statsClient = .previewValue
    } operation: {
        DeckListModel()
    }
    model.state = .loaded(
        rows: [
            DeckRowViewData(
                id: 1, name: "한국어", fullName: "한국어",
                newCount: 20, learnCount: 93, reviewCount: 74,
                isFiltered: false, subdeckCount: 4
            ),
            DeckRowViewData(
                id: 2, name: "English", fullName: "English",
                newCount: 0, learnCount: 67, reviewCount: 200,
                isFiltered: false, subdeckCount: 0
            ),
            DeckRowViewData(
                id: 3, name: "Hardest cards", fullName: "Hardest cards",
                newCount: 0, learnCount: 0, reviewCount: 24,
                isFiltered: true, subdeckCount: 0
            ),
        ],
        hero: HeroData(
            totalDue: 478, deckCount: 3, streak: 36,
            last14Days: [3, 5, 2, 7, 6, 9, 4, 8, 6, 5, 7, 3, 8, 5]
        ),
        heatmap: .empty
    )
    return NavigationStack {
        DeckListView(model: model)
    }
    .environment(\.palette, .vividLight)
}

#Preview("Minimal") {
    // Same seeded state as the default preview — mirrors it but pins the
    // minimal theme's light palette to eyeball ring elevation + monogram
    // tiles + cobalt accent.
    let model = withDependencies {
        $0.deckClient = .previewValue
        $0.statsClient = .previewValue
    } operation: {
        DeckListModel()
    }
    model.state = .loaded(
        rows: [
            DeckRowViewData(
                id: 1, name: "한국어", fullName: "한국어",
                newCount: 20, learnCount: 93, reviewCount: 74,
                isFiltered: false, subdeckCount: 4
            ),
            DeckRowViewData(
                id: 2, name: "English", fullName: "English",
                newCount: 0, learnCount: 67, reviewCount: 200,
                isFiltered: false, subdeckCount: 0
            ),
            DeckRowViewData(
                id: 3, name: "Hardest cards", fullName: "Hardest cards",
                newCount: 0, learnCount: 0, reviewCount: 24,
                isFiltered: true, subdeckCount: 0
            ),
        ],
        hero: HeroData(
            totalDue: 478, deckCount: 3, streak: 36,
            last14Days: [3, 5, 2, 7, 6, 9, 4, 8, 6, 5, 7, 3, 8, 5]
        ),
        heatmap: .empty
    )
    return NavigationStack {
        DeckListView(model: model)
    }
    .environment(\.palette, ThemeRegistry.shared.palette(id: .minimal, scheme: .light))
}
#endif
