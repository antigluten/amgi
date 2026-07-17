// iOS-only component — Menu/popover/listRowSeparator APIs are unavailable on watchOS.
#if !os(watchOS)
public import SwiftUI
import AmgiTheme

/// Pure rendering surface for the Library screen. Owns no I/O. Takes a
/// single state value + callbacks for mutations. The container in the
/// app target maps domain rows (`DeckListRow` etc.) to `DeckRowViewData`
/// and reconstructs domain types from callback payloads.
public struct LibraryListContent: View {
    public enum State: Equatable, Hashable, Sendable {
        case loading
        case empty
        case loaded(rows: [DeckRowViewData], hero: HeroData, heatmap: HeatmapCardData)
    }

    let state: State
    let onRefresh: () async -> Void
    let onStartReview: () -> Void
    let onTapDeck: (DeckRowViewData) -> Void
    let onDeleteDeck: (Int64) async -> Void
    let onRenameDeck: (DeckRowViewData) -> Void

    @Environment(\.palette) private var palette

    public init(
        state: State,
        onRefresh: @escaping () async -> Void,
        onStartReview: @escaping () -> Void,
        onTapDeck: @escaping (DeckRowViewData) -> Void,
        onDeleteDeck: @escaping (Int64) async -> Void,
        onRenameDeck: @escaping (DeckRowViewData) -> Void
    ) {
        self.state = state
        self.onRefresh = onRefresh
        self.onStartReview = onStartReview
        self.onTapDeck = onTapDeck
        self.onDeleteDeck = onDeleteDeck
        self.onRenameDeck = onRenameDeck
    }

    public var body: some View {
        switch state {
        case .loading:
            ProgressView()
        case .empty:
            ContentUnavailableView(
                "No Decks",
                systemImage: "rectangle.stack",
                description: Text("Sync with your server to get your decks.")
            )
        case .loaded(let rows, let hero, let heatmap):
            loadedList(rows: rows, hero: hero, heatmap: heatmap)
        }
    }

    @ViewBuilder
    private func loadedList(rows: [DeckRowViewData], hero: HeroData, heatmap: HeatmapCardData) -> some View {
        List {
            Section {
                LibraryHeroCard(data: hero, onStartReview: onStartReview)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section("Decks") {
                ForEach(rows) { row in
                    DeckListRowView(
                        data: row,
                        onTap: { onTapDeck(row) },
                        onDelete: { Task { await onDeleteDeck(row.id) } },
                        onRename: { onRenameDeck(row) }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(palette.surfaceElevated)
                    .listRowSeparatorTint(palette.separator)
                }
            }

            Section {
                ActivityHeatmapCard(data: heatmap)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .libraryListStyle()
        .scrollContentBackground(.hidden)
        .refreshable { await onRefresh() }
    }
}

private extension View {
    /// `insetGrouped` is iOS-only. On macOS (preview-only target),
    /// fall back to the platform default.
    @ViewBuilder
    func libraryListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self
        #endif
    }
}

// MARK: - Previews

#if DEBUG
private extension DeckRowViewData {
    static let sampleKorean = DeckRowViewData(
        id: 1, name: "한국어", fullName: "한국어",
        newCount: 20, learnCount: 93, reviewCount: 74,
        isFiltered: false, subdeckCount: 4
    )
    static let sampleEnglish = DeckRowViewData(
        id: 2, name: "English", fullName: "English",
        newCount: 0, learnCount: 67, reviewCount: 200,
        isFiltered: false, subdeckCount: 0
    )
    static let sampleCS = DeckRowViewData(
        id: 3, name: "ComputerScience", fullName: "ComputerScience",
        newCount: 20, learnCount: 35, reviewCount: 72,
        isFiltered: false, subdeckCount: 0
    )
    static let sampleEspanol = DeckRowViewData(
        id: 4, name: "Español", fullName: "Español",
        newCount: 0, learnCount: 0, reviewCount: 0,
        isFiltered: false, subdeckCount: 0
    )
    static let sampleFiltered = DeckRowViewData(
        id: 5, name: "Hardest cards", fullName: "Hardest cards",
        newCount: 0, learnCount: 0, reviewCount: 24,
        isFiltered: true, subdeckCount: 0
    )
}

private extension HeroData {
    static let samplePopulated = HeroData(
        totalDue: 680, deckCount: 7, streak: 36,
        last14Days: [3, 5, 2, 7, 6, 9, 4, 8, 6, 5, 7, 3, 8, 5]
    )
}

#Preview("Loaded — populated") {
    NavigationStack {
        LibraryListContent(
            state: .loaded(
                rows: [.sampleKorean, .sampleEnglish, .sampleCS, .sampleEspanol, .sampleFiltered],
                hero: .samplePopulated,
                heatmap: .dense
            ),
            onRefresh: {}, onStartReview: {},
            onTapDeck: { _ in }, onDeleteDeck: { _ in }, onRenameDeck: { _ in }
        )
        .navigationTitle("Library")
    }
    .environment(\.palette, .vividLight)
}

#Preview("Loaded — zero due") {
    NavigationStack {
        LibraryListContent(
            state: .loaded(
                rows: [.sampleEspanol],
                hero: HeroData(totalDue: 0, deckCount: 1, streak: 12,
                               last14Days: Array(repeating: 0, count: 14)),
                heatmap: .sparse
            ),
            onRefresh: {}, onStartReview: {},
            onTapDeck: { _ in }, onDeleteDeck: { _ in }, onRenameDeck: { _ in }
        )
        .navigationTitle("Library")
    }
    .environment(\.palette, .vividLight)
}

#Preview("Loading") {
    NavigationStack {
        LibraryListContent(
            state: .loading,
            onRefresh: {}, onStartReview: {},
            onTapDeck: { _ in }, onDeleteDeck: { _ in }, onRenameDeck: { _ in }
        )
        .navigationTitle("Library")
    }
    .environment(\.palette, .vividLight)
}

#Preview("Empty") {
    NavigationStack {
        LibraryListContent(
            state: .empty,
            onRefresh: {}, onStartReview: {},
            onTapDeck: { _ in }, onDeleteDeck: { _ in }, onRenameDeck: { _ in }
        )
        .navigationTitle("Library")
    }
    .environment(\.palette, .vividLight)
}
#endif
#endif  // !os(watchOS)
