//
//  LibraryListContent.swift
//  UI
//
//  Created by Vladimir Gusev on 15.05.2026.
//

// iOS-only component — Menu/popover/listRowSeparator APIs are unavailable on watchOS.
#if !os(watchOS)
public import SwiftUI
import Theme

public struct LibraryListContent: View {
    public enum State: Equatable, Hashable, Sendable {
        case loading
        case empty
        case failed(String)
        case loaded(rows: [DeckRowViewData], hero: HeroData, heatmap: HeatmapCardData?)
    }

    let state: State
    let selectedDeckID: Int64?
    let onRefresh: () async -> Void
    let onStartReview: () -> Void
    let onTapDeck: (DeckRowViewData) -> Void
    let onDeleteDeck: (Int64) async -> Void
    let onRenameDeck: (DeckRowViewData) -> Void
    let onCreateDeck: () -> Void

    @AppStorage("appearance_deck_layout") private var layout: DeckLayout = .list

    public init(
        state: State,
        selectedDeckID: Int64? = nil,
        onRefresh: @escaping () async -> Void,
        onStartReview: @escaping () -> Void,
        onTapDeck: @escaping (DeckRowViewData) -> Void,
        onDeleteDeck: @escaping (Int64) async -> Void,
        onRenameDeck: @escaping (DeckRowViewData) -> Void,
        onCreateDeck: @escaping () -> Void
    ) {
        self.state = state
        self.selectedDeckID = selectedDeckID
        self.onRefresh = onRefresh
        self.onStartReview = onStartReview
        self.onTapDeck = onTapDeck
        self.onDeleteDeck = onDeleteDeck
        self.onRenameDeck = onRenameDeck
        self.onCreateDeck = onCreateDeck
    }

    public var body: some View {
        switch state {
        case .loading:
            ProgressView()
        case .empty:
            ContentUnavailableView {
                Label("No Decks", systemImage: "rectangle.stack")
            } description: {
                Text("Sync with your server, or create a deck to get started.")
            } actions: {
                Button("Create Deck", action: onCreateDeck)
                    .buttonStyle(.borderedProminent)
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load Decks", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await onRefresh() } }
                    .buttonStyle(.borderedProminent)
            }
        case .loaded(let rows, let hero, let heatmap):
            loadedList(rows: rows, hero: hero, heatmap: heatmap)
        }
    }

    @ViewBuilder
    private func loadedList(rows: [DeckRowViewData], hero: HeroData, heatmap: HeatmapCardData?) -> some View {
        List {
            Section {
                LibraryHeroCard(
                    data: hero,
                    activityPending: heatmap == nil,
                    onStartReview: onStartReview
                )
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                switch layout {
                case .list:
                    ForEach(rows) { row in
                        DeckListRowView(
                            data: row,
                            isSelected: row.id == selectedDeckID,
                            onTap: { onTapDeck(row) },
                            onDelete: { Task { await onDeleteDeck(row.id) } },
                            onRename: { onRenameDeck(row) }
                        )
                        .modifier(DeckRowChrome(isSelected: row.id == selectedDeckID))
                    }
                case .grid:
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: AmgiSpacing.md)],
                        spacing: AmgiSpacing.md
                    ) {
                        ForEach(rows) { row in
                            DeckGridCardView(
                                data: row,
                                isSelected: row.id == selectedDeckID,
                                onTap: { onTapDeck(row) },
                                onDelete: { Task { await onDeleteDeck(row.id) } },
                                onRename: { onRenameDeck(row) }
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                deckSectionHeader
            }

            Section {
                ActivityHeatmapCard(data: heatmap ?? .empty)
                    .redacted(reason: heatmap == nil ? .placeholder : [])
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .libraryListStyle()
        .scrollContentBackground(.hidden)
        .refreshable { await onRefresh() }
    }

    private var deckSectionHeader: some View {
        HStack {
            Text("Decks")
            Spacer()
            Picker("Deck view", selection: $layout) {
                ForEach(DeckLayout.allCases) { option in
                    Label(option.label, systemImage: option.symbol).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelStyle(.iconOnly)
            .labelsHidden()
            .frame(width: 96)
        }
        .textCase(nil)
    }
}

private struct DeckRowChrome: ViewModifier {
    let isSelected: Bool

    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(isSelected ? palette.accentSoft : palette.surfaceElevated)
            .listRowSeparatorTint(palette.separator)
    }
}

extension LibraryListContent: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.state == rhs.state && lhs.selectedDeckID == rhs.selectedDeckID
    }
}

private extension View {
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
            onTapDeck: { _ in }, onDeleteDeck: { _ in }, onRenameDeck: { _ in }, onCreateDeck: {}
        )
        .navigationTitle("Library")
    }
    .environment(\.palette, .vividLight)
}

#Preview("Loaded — Minimal palette") {
    NavigationStack {
        LibraryListContent(
            state: .loaded(
                rows: [.sampleKorean, .sampleEnglish, .sampleCS, .sampleEspanol, .sampleFiltered],
                hero: .samplePopulated,
                heatmap: .dense
            ),
            onRefresh: {}, onStartReview: {},
            onTapDeck: { _ in }, onDeleteDeck: { _ in }, onRenameDeck: { _ in }, onCreateDeck: {}
        )
        .navigationTitle("Library")
    }
    .environment(\.palette, ThemeRegistry.shared.palette(id: .minimal, scheme: .light))
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
            onTapDeck: { _ in }, onDeleteDeck: { _ in }, onRenameDeck: { _ in }, onCreateDeck: {}
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
            onTapDeck: { _ in }, onDeleteDeck: { _ in }, onRenameDeck: { _ in }, onCreateDeck: {}
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
            onTapDeck: { _ in }, onDeleteDeck: { _ in }, onRenameDeck: { _ in }, onCreateDeck: {}
        )
        .navigationTitle("Library")
    }
    .environment(\.palette, .vividLight)
}
#endif
#endif  // !os(watchOS)
