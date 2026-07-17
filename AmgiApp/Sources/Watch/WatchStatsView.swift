import AnkiClients
import AnkiKit
import Dependencies
import SwiftUI

struct WatchStatsView: View {
    @Dependency(\.statsClient) var statsClient
    @Dependency(\.deckClient) var deckClient
    @State private var graphs: GraphsSnapshot?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var period: StatsPeriod = .month
    @State private var decks: [DeckInfo] = []
    @State private var selectedDeck: DeckInfo?
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if let graphs {
                List {
                    Section {
                        deckPicker
                        periodPicker
                    }
                    Group {
                        PeriodStatsCard(period: period, today: graphs.today, reviews: graphs.reviews)
                        FutureDueChart(futureDue: graphs.futureDue, period: period)
                        ReviewsChart(reviews: graphs.reviews, period: period)
                        CardCountsChart(cardCounts: graphs.cardCounts)
                        IntervalsChart(intervals: graphs.intervals)
                        EaseChart(eases: graphs.eases)
                        HourlyChart(hours: graphs.hours, period: period)
                        ButtonsChart(buttons: graphs.buttons, period: period)
                        AddedChart(added: graphs.added, period: period)
                        RetentionChart(trueRetention: graphs.trueRetention)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("Stats")
        .task {
            await loadDecks()
            await loadStats()
        }
        .onChange(of: selectedDeck) { _, _ in
            Task { await loadStats() }
        }
        .onChange(of: period) { _, _ in
            Task { await loadStats() }
        }
    }
    private var deckPicker: some View {
        Picker(selection: $selectedDeck) {
            Text("Collection").tag(nil as DeckInfo?)
            ForEach(decks.filter({ !$0.name.contains("::") })) { deck in
                Text(deck.name).tag(deck as DeckInfo?)
            }
        } label: {
            Text("Deck")
        }
    }
    private var periodPicker: some View {
        Picker(selection: $period) {
            ForEach(StatsPeriod.allCases, id: \.self) { p in
                Text(p.rawValue).tag(p)
            }
        } label: {
            Text("Period")
        }
    }
    private func loadDecks() async {
        decks = (try? await deckClient.fetchAll()) ?? []
    }
    private func loadStats() async {
        isLoading = graphs == nil
        do {
            let search = selectedDeck.map { "deck:\"\($0.name)\"" } ?? ""
            graphs = try await statsClient.fetchGraphs(search, period.days)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
