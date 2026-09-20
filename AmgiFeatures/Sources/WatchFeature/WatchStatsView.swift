//
//  WatchStatsView.swift
//  WatchFeature
//
//  Created by Leaf Eriksen on 17.07.2026.
//

import StatsCharts
import AnkiClients
import AnkiKit
import Dependencies
import os
import SwiftUI

private let logger = Logger(subsystem: "com.amgiapp.AmgiApp", category: "WatchStats")

struct WatchStatsView: View {
    @Dependency(\.statsClient) var statsClient
    @Dependency(\.deckClient) var deckClient
    /// One axis instead of an `isLoading` / `graphs?` / `errorMessage?` trio,
    /// which had eight combinations for three renderable states — including
    /// "not loading, no graphs, no error", which rendered nothing at all.
    enum LoadState {
        case loading
        case loaded(GraphsSnapshot)
        case failed(String)
    }

    @State private var state: LoadState = .loading
    @State private var period: StatsPeriod = .month
    @State private var decks: [DeckInfo] = []
    @State private var selectedDeck: DeckInfo?
    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Loading statistics...")
            case .failed(let error):
                ContentUnavailableView {
                    Label("Couldn't Load Stats", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") { Task { await loadStats() } }
                }
            case .loaded(let graphs):
                List {
                    Section {
                        deckPicker
                        periodPicker
                    }
                    Group {
                        StatsChartStack(graphs: graphs, period: period, isCompact: true)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("Stats")
        .task { await loadDecks() }
        // Keyed on the two inputs the query is built from, so changing either
        // cancels the in-flight fetch instead of racing it.
        .task(id: StatsQuery(deck: selectedDeck, period: period)) {
            await loadStats()
        }
    }

    /// The inputs `loadStats` reads, as one `.task(id:)` key.
    private struct StatsQuery: Equatable {
        let deck: DeckInfo?
        let period: StatsPeriod
    }
    private var deckPicker: some View {
        Picker(selection: $selectedDeck) {
            Text("Collection").tag(nil as DeckInfo?)
            ForEach(decks) { deck in
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
        do {
            decks = try await deckClient.fetchAll().filter { !$0.name.contains("::") }
        } catch {
            logger.error("Deck load error: \(error)")
            decks = []
        }
    }
    private func loadStats() async {
        do {
            let search = selectedDeck.map { DeckSearch.term($0.name) } ?? ""
            let graphs = try await statsClient.fetchGraphs(search, period.days)
            guard !Task.isCancelled else { return }
            state = .loaded(graphs)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error.localizedDescription)
        }
    }
}
