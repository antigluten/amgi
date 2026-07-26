public import SwiftUI
import AmgiTheme

/// Pure presentation layer for the deck-detail screen. Holds no I/O —
/// drives entirely off `DeckDetailViewState`. The Container in AmgiApp
/// performs the data fetches and pipes a `DeckDetailViewData` in.
///
/// Composition top→bottom (matches `design/deck.jsx`):
///   • Hero — flag tile + large title + subtitle (+ Custom Study chip)
///   • DeckDetailTile — NEW / LEARNING / REVIEW counts
///   • DeckStudyButton — full-width Study Now pill
///   • DeckCustomStudyCard — filtered decks only (Rebuild / Empty)
///   • DeckSubdecksCard — if children
///   • heatmapSlot — Container-injected (R03)
///   • InsightsCard
public struct DeckDetailScreen<HeatmapSlot: View>: View {
    public enum Action: Equatable, Sendable {
        case studyNow
        case rebuild
        case emptyDeck
        case subdeckSelected(DeckSubdeckRowData)
    }

    public let state: DeckDetailViewState
    public let heatmapSlot: () -> HeatmapSlot
    public let onAction: (Action) -> Void

    @Environment(\.palette) private var palette

    public init(
        state: DeckDetailViewState,
        @ViewBuilder heatmapSlot: @escaping () -> HeatmapSlot,
        onAction: @escaping (Action) -> Void
    ) {
        self.state = state
        self.heatmapSlot = heatmapSlot
        self.onAction = onAction
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                heroSection
                statsSection
                ctaSection
                customStudySection
                subdecksSection
                heatmapSection
                insightsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 32)
        }
        .background(palette.background.ignoresSafeArea())
    }

    // MARK: - Sections

    @ViewBuilder
    private var heroSection: some View {
        switch state {
        case .loading:
            DeckHero(title: "…", subtitle: "Loading…", tone: palette.border, glyph: "📚", isFiltered: false)
        case .loaded(let data):
            DeckHero(
                title: data.title,
                subtitle: data.subtitle,
                tone: data.tone,
                glyph: data.glyph,
                isFiltered: data.isFiltered
            )
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        switch state {
        case .loading:
            DeckDetailTile(data: .zero)
                .redacted(reason: .placeholder)
        case .loaded(let data):
            DeckDetailTile(data: data.tileCounts)
        }
    }

    @ViewBuilder
    private var ctaSection: some View {
        switch state {
        case .loading:
            DeckStudyButton(isDisabled: true, onTap: {})
        case .loaded(let data):
            DeckStudyButton(isDisabled: data.isEmpty) { onAction(.studyNow) }
        }
    }

    @ViewBuilder
    private var customStudySection: some View {
        if case .loaded(let data) = state, data.isFiltered {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("CUSTOM STUDY")
                DeckCustomStudyCard(
                    isActionInFlight: data.isActionInFlight,
                    onRebuild: { onAction(.rebuild) },
                    onEmpty: { onAction(.emptyDeck) }
                )
            }
        }
    }

    @ViewBuilder
    private var subdecksSection: some View {
        if case .loaded(let data) = state, !data.subdecks.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("SUBDECKS")
                DeckSubdecksCard(rows: data.subdecks) { row in
                    onAction(.subdeckSelected(row))
                }
            }
        }
    }

    @ViewBuilder
    private var heatmapSection: some View {
        if case .loaded = state {
            heatmapSlot()
        }
    }

    @ViewBuilder
    private var insightsSection: some View {
        if case .loaded(let data) = state {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("INSIGHTS")
                InsightsCard(data: data.insights)
            }
        }
    }

    // MARK: - Row primitives

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(0.4)
            .foregroundStyle(palette.textTertiary)
            .padding(.leading, 4)
            .padding(.top, 6)
    }
}

// MARK: - Previews

#if DEBUG
private let _krChildren: [DeckSubdeckRowData] = [
    DeckSubdeckRowData(id: 1, name: "Vocab Typing", fullName: "한국어::Vocab Typing", newCount: 20, learnCount: 0, reviewCount: 5, isFiltered: false),
    DeckSubdeckRowData(id: 2, name: "Cloze Grammar", fullName: "한국어::Cloze Grammar", newCount: 0, learnCount: 4, reviewCount: 9, isFiltered: false),
    DeckSubdeckRowData(id: 3, name: "Collocations", fullName: "한국어::Collocations", newCount: 0, learnCount: 14, reviewCount: 0, isFiltered: false),
    DeckSubdeckRowData(id: 4, name: "Manual Tags", fullName: "한국어::Manual Tags", newCount: 20, learnCount: 3, reviewCount: 3, isFiltered: false),
]

private let _krDefault = DeckDetailViewData(
    title: "한국어",
    subtitle: "Last studied today · 32-day streak",
    tone: .red,
    glyph: "🇰🇷",
    tileCounts: DeckDetailTileData(newCount: 20, learnCount: 93, reviewCount: 74),
    isFiltered: false,
    isEmpty: false,
    subdecks: _krChildren,
    insights: InsightsCardData(retention30dPercent: 86, avgCardsPerDay: 59, matureCards: 200),
    isActionInFlight: false
)

private let _krFiltered = DeckDetailViewData(
    title: "한국어 (Filtered)",
    subtitle: "Last studied today · 32-day streak",
    tone: .red,
    glyph: "🇰🇷",
    tileCounts: DeckDetailTileData(newCount: 20, learnCount: 93, reviewCount: 74),
    isFiltered: true,
    isEmpty: false,
    subdecks: [],
    insights: InsightsCardData(retention30dPercent: 86, avgCardsPerDay: 59, matureCards: 200),
    isActionInFlight: false
)

private let _krEmpty = DeckDetailViewData(
    title: "한국어",
    subtitle: "No cards yet · Add some to start studying",
    tone: .red,
    glyph: "🇰🇷",
    tileCounts: .zero,
    isFiltered: false,
    isEmpty: true,
    subdecks: [],
    insights: .empty,
    isActionInFlight: false
)

#Preview("Default") {
    NavigationStack {
        DeckDetailScreen(
            state: .loaded(_krDefault),
            heatmapSlot: { EmptyView() },
            onAction: { _ in }
        )
    }
    .environment(\.palette, .vividLight)
}

#Preview("Filtered") {
    NavigationStack {
        DeckDetailScreen(
            state: .loaded(_krFiltered),
            heatmapSlot: { EmptyView() },
            onAction: { _ in }
        )
    }
    .environment(\.palette, .vividLight)
}

#Preview("Empty") {
    NavigationStack {
        DeckDetailScreen(
            state: .loaded(_krEmpty),
            heatmapSlot: { EmptyView() },
            onAction: { _ in }
        )
    }
    .environment(\.palette, .vividLight)
}

#Preview("Loading") {
    NavigationStack {
        DeckDetailScreen(
            state: .loading,
            heatmapSlot: { EmptyView() },
            onAction: { _ in }
        )
    }
    .environment(\.palette, .vividLight)
}

#Preview("Default — dark") {
    NavigationStack {
        DeckDetailScreen(
            state: .loaded(_krDefault),
            heatmapSlot: { EmptyView() },
            onAction: { _ in }
        )
    }
    .environment(\.palette, .vividDark)
    .preferredColorScheme(.dark)
}

#Preview("With heatmap slot") {
    NavigationStack {
        DeckDetailScreen(
            state: .loaded(_krDefault),
            heatmapSlot: {
                Rectangle()
                    .fill(Color.blue.opacity(0.10))
                    .frame(height: 80)
                    .overlay(Text("heatmap (R03)").font(.caption).foregroundStyle(.secondary))
            },
            onAction: { _ in }
        )
    }
    .environment(\.palette, .vividLight)
}
#endif
