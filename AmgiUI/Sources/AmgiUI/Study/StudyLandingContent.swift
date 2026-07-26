public import SwiftUI
import AmgiTheme

/// Pure rendering surface for the Study landing screen. Owns no I/O.
/// The container in the app target loads data and maps it to the
/// single `State` value passed here.
public struct StudyLandingContent: View {
    public enum State: Equatable, Sendable {
        case loading
        case empty
        case loaded(
            summary: StudySummaryData,
            decks: [StudyDeckRowData],
            readingRecs: [StudyReadingRecData]
        )
    }

    let state: State
    let onBeginSession: () -> Void
    let onSelectDeck: (Int64) -> Void
    let onSelectBook: (String) -> Void
    let onRefresh: () async -> Void

    @Environment(\.palette) private var palette

    public init(
        state: State,
        onBeginSession: @escaping () -> Void,
        onSelectDeck: @escaping (Int64) -> Void,
        onSelectBook: @escaping (String) -> Void,
        onRefresh: @escaping () async -> Void
    ) {
        self.state = state
        self.onBeginSession = onBeginSession
        self.onSelectDeck = onSelectDeck
        self.onSelectBook = onSelectBook
        self.onRefresh = onRefresh
    }

    public var body: some View {
        switch state {
        case .loading:
            loadingView
        case .empty:
            emptyView
        case let .loaded(summary, decks, readingRecs):
            loadedScrollView(summary: summary, decks: decks, readingRecs: readingRecs)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty

    private var emptyView: some View {
        ContentUnavailableView(
            "No decks yet",
            systemImage: "graduationcap",
            description: Text("Add an Anki deck to get started.")
        )
    }

    // MARK: - Loaded scroll view (whole page scrolls, no pinned hero)

    private func loadedScrollView(
        summary: StudySummaryData,
        decks: [StudyDeckRowData],
        readingRecs: [StudyReadingRecData]
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                inlineHeader(summary: summary)
                ringHero(summary: summary)
                beginButton(totalDue: summary.totalDue)
                    .padding(.top, 20)
                loadedBody(summary: summary, decks: decks, readingRecs: readingRecs)
                    .padding(.top, 8)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable { await onRefresh() }
    }

    // MARK: - Inline header

    private func inlineHeader(summary: StudySummaryData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary.todayLabel)
                .amgiFont(.displayHero)
                .foregroundStyle(palette.textPrimary)
            Text(summary.subtitleLabel)
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ring (scrolls with page)

    private func ringHero(summary: StudySummaryData) -> some View {
        StudyDueRing(summary: summary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Begin button

    private func beginButton(totalDue: Int) -> some View {
        Button(action: onBeginSession) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(totalDue > 0 ? "Begin session · \(totalDue) cards" : "Nothing due")
                    .amgiFont(.body)
                    .bold()
            }
            .foregroundStyle(totalDue > 0 ? .white : palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                totalDue > 0 ? palette.accent : palette.accentSoft,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .disabled(totalDue == 0)
        .animation(.easeInOut(duration: 0.2), value: totalDue)
    }

    // MARK: - Loaded content body

    @ViewBuilder
    private func loadedBody(
        summary: StudySummaryData,
        decks: [StudyDeckRowData],
        readingRecs: [StudyReadingRecData]
    ) -> some View {
        upNextSection(decks: decks)
        if !readingRecs.isEmpty {
            readingRecsSection(readingRecs: readingRecs)
        }
    }

    // MARK: - Up Next

    @ViewBuilder
    private func upNextSection(decks: [StudyDeckRowData]) -> some View {
        if !decks.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Up Next")
                    .padding(.bottom, 4)
                VStack(spacing: 0) {
                    ForEach(decks) { deck in
                        StudyDeckRow(data: deck) { onSelectDeck(deck.id) }
                            .padding(.horizontal, 12)
                        if deck.id != decks.last?.id {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.surfaceElevated)
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                )
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Reading recommendations

    @ViewBuilder
    private func readingRecsSection(readingRecs: [StudyReadingRecData]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Reading recommendations")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(readingRecs) { rec in
                        StudyReadingRec(data: rec) { onSelectBook(rec.id) }
                    }
                }
                .padding(.horizontal, 1)  // prevents clip at edge
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .amgiFont(.sectionHeading)
            .foregroundStyle(palette.textPrimary)
            .padding(.bottom, 8)
    }
}

// MARK: - Previews

#if DEBUG

private let busySummary = StudySummaryData(
    totalDue: 55,
    newCount: 25,
    learnCount: 17,
    reviewCount: 13,
    todayLabel: "Today",
    subtitleLabel: "Wednesday · 3 decks due",
    deckCount: 3
)

private let busyDecks: [StudyDeckRowData] = [
    StudyDeckRowData(id: 1, name: "한국어 · Vocab Typing", totalDue: 25,
                     newCount: 10, learnCount: 8, reviewCount: 7, isFiltered: false),
    StudyDeckRowData(id: 2, name: "ComputerScience", totalDue: 17,
                     newCount: 8, learnCount: 5, reviewCount: 4, isFiltered: false),
    StudyDeckRowData(id: 3, name: "Français", totalDue: 13,
                     newCount: 7, learnCount: 4, reviewCount: 2, isFiltered: false),
]

private let sampleRecs: [StudyReadingRecData] = [
    StudyReadingRecData(id: "lp", title: "어린 왕자",
                        coverImagePath: nil, authorLabel: "Antoine de Saint-Exupéry"),
    StudyReadingRecData(id: "nw", title: "Norwegian Wood",
                        coverImagePath: nil, authorLabel: "Haruki Murakami"),
    StudyReadingRecData(id: "dq", title: "Don Quijote",
                        coverImagePath: nil, authorLabel: "Miguel de Cervantes"),
]

#Preview("Busy day") {
    NavigationStack {
        StudyLandingContent(
            state: .loaded(summary: busySummary, decks: busyDecks, readingRecs: sampleRecs),
            onBeginSession: {},
            onSelectDeck: { _ in },
            onSelectBook: { _ in },
            onRefresh: {}
        )
    }
    .environment(\.palette, .vividLight)
}

#Preview("All done") {
    NavigationStack {
        StudyLandingContent(
            state: .loaded(
                summary: StudySummaryData(
                    totalDue: 0, newCount: 0, learnCount: 0, reviewCount: 0,
                    todayLabel: "Today", subtitleLabel: "Wednesday", deckCount: 0
                ),
                decks: [],
                readingRecs: sampleRecs
            ),
            onBeginSession: {},
            onSelectDeck: { _ in },
            onSelectBook: { _ in },
            onRefresh: {}
        )
    }
    .environment(\.palette, .vividLight)
}

#Preview("Loading") {
    NavigationStack {
        StudyLandingContent(
            state: .loading,
            onBeginSession: {},
            onSelectDeck: { _ in },
            onSelectBook: { _ in },
            onRefresh: {}
        )
    }
    .environment(\.palette, .vividLight)
}

#Preview("Empty") {
    NavigationStack {
        StudyLandingContent(
            state: .empty,
            onBeginSession: {},
            onSelectDeck: { _ in },
            onSelectBook: { _ in },
            onRefresh: {}
        )
    }
    .environment(\.palette, .vividLight)
}
#endif
