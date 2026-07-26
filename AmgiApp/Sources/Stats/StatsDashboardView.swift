import SwiftUI
import AmgiTheme
import AnkiKit
import AnkiClients
import Dependencies

struct StatsDashboardView: View {
    @Environment(\.palette) private var palette

    @State private var model = StatsDashboardModel()
    @State private var period: StatsPeriod = .month
    @State private var selectedDeck: DeckInfo?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AmgiSpacing.lg) {
                if model.isLoading {
                    ProgressView("Loading statistics...")
                        .padding(.top, 40)
                } else if let error = model.errorMessage {
                    ContentUnavailableView(
                        "Failed to Load Stats",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if let graphs = model.graphs {
                    // Filters row
                    HStack(spacing: AmgiSpacing.sm) {
                        deckMenu
                        periodMenu
                        Spacer()
                    }

                    PeriodStatsCard(period: period, today: graphs.today, reviews: graphs.reviews)
                    FutureDueChart(futureDue: graphs.futureDue, period: period)
                    HeatmapChartOptimized(reviews: graphs.reviews)
                    ReviewsChart(reviews: graphs.reviews, period: period)
                    CardCountsChart(cardCounts: graphs.cardCounts)
                    IntervalsChart(intervals: graphs.intervals)
                    EaseChart(eases: graphs.eases)
                    HourlyChart(hours: graphs.hours, period: period)
                    ButtonsChart(buttons: graphs.buttons, period: period)
                    AddedChart(added: graphs.added, period: period)
                    RetentionChart(trueRetention: graphs.trueRetention)
                    RetrievabilityChart(retrievability: graphs.retrievability)
                }
            }
            .padding(AmgiSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background(palette.surface)
        .navigationTitle("Statistics")
        .task {
            await model.loadDecks()
            await reloadStats()
        }
        .onAppear {
            Task { await reloadStats() }
        }
        .refreshable { await reloadStats() }
        .onChange(of: selectedDeck) {
            Task { await reloadStats() }
        }
        .onChange(of: period) {
            Task { await reloadStats() }
        }
    }

    // MARK: - Deck Menu

    private var deckMenu: some View {
        Menu {
            Button { selectedDeck = nil } label: {
                if selectedDeck == nil { Label("Whole Collection", systemImage: "checkmark") }
                else { Text("Whole Collection") }
            }
            Divider()
            ForEach(model.decks.filter({ !$0.name.contains("::") })) { deck in
                Button { selectedDeck = deck } label: {
                    if selectedDeck?.id == deck.id { Label(deck.name, systemImage: "checkmark") }
                    else { Text(deck.name) }
                }
            }
        } label: {
            filterCapsule(
                icon: "rectangle.stack",
                label: selectedDeck?.name ?? "Collection"
            )
        }
    }

    // MARK: - Period Menu

    private var periodMenu: some View {
        Menu {
            ForEach(StatsPeriod.allCases, id: \.self) { p in
                Button { period = p } label: {
                    if period == p { Label(p.rawValue, systemImage: "checkmark") }
                    else { Text(p.rawValue) }
                }
            }
        } label: {
            filterCapsule(
                icon: "calendar",
                label: period.shortLabel
            )
        }
    }

    // MARK: - Shared Capsule

    // MARK: - Data
}

private extension StatsDashboardView {
    func filterCapsule(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .fontWeight(.medium)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8))
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemFill))
        .clipShape(Capsule())
    }

    /// Bridge the view's filter state into the model's stats load.
    func reloadStats() async {
        let search = selectedDeck.map { "deck:\"\($0.name)\"" } ?? ""
        await model.loadStats(search: search, days: period.days)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    // `prepareDependencies` sets the defaults the view reads via @Dependency in
    // its body; `.previewValue` returns a fully-populated snapshot so every
    // chart renders.
    let _ = prepareDependencies {
        $0.statsClient = .previewValue
        $0.deckClient = .previewValue
    }
    NavigationStack {
        StatsDashboardView()
    }
}
#endif
