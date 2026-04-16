import SwiftUI
import AnkiKit
import AnkiClients
import AnkiProto
import Dependencies
import SwiftProtobuf

struct StatsDashboardView: View {
    @Dependency(\.statsClient) var statsClient
    @Dependency(\.deckClient) var deckClient

    @State private var graphs: Anki_Stats_GraphsResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var period: StatsPeriod = .month
    @State private var decks: [DeckInfo] = []
    @State private var selectedDeck: DeckInfo?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AmgiSpacing.lg) {
                if isLoading {
                    ProgressView("Loading statistics...")
                        .padding(.top, 40)
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Failed to Load Stats",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if let graphs {
                    // Filters row
                    HStack(spacing: AmgiSpacing.sm) {
                        deckMenu
                        periodMenu
                        Spacer()
                    }

                    PeriodStatsCard(period: period, today: graphs.today, reviews: graphs.reviews)
                    FutureDueChart(futureDue: graphs.futureDue, period: period)
                    HeatmapChart(reviews: graphs.reviews)
                    ReviewsChart(reviews: graphs.reviews, period: period)
                    CardCountsChart(cardCounts: graphs.cardCounts)
                    IntervalsChart(intervals: graphs.intervals)
                    EaseChart(eases: graphs.eases)
                    HourlyChart(hours: graphs.hours, period: period)
                    ButtonsChart(buttons: graphs.buttons, period: period)
                    AddedChart(added: graphs.added, period: period)
                    RetentionChart(trueRetention: graphs.trueRetention)
                }
            }
            .padding(AmgiSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background(Color.amgiSurface)
        .navigationTitle("Statistics")
        .task {
            await loadDecks()
            await loadStats()
        }
        .onAppear {
            Task { await loadStats() }
        }
        .refreshable { await loadStats() }
        .onChange(of: selectedDeck) {
            Task { await loadStats() }
        }
        .onChange(of: period) {
            Task { await loadStats() }
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
            ForEach(decks.filter({ !$0.name.contains("::") })) { deck in
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

    private func filterCapsule(icon: String, label: String) -> some View {
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

    // MARK: - Data

    private func loadDecks() async {
        decks = (try? deckClient.fetchAll()) ?? []
    }

    private func loadStats() async {
        isLoading = graphs == nil
        do {
            let search = selectedDeck.map { "deck:\"\($0.name)\"" } ?? ""
            let data = try statsClient.fetchGraphs(search, UInt32(period.days))
            graphs = try Anki_Stats_GraphsResponse(serializedBytes: data)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
