//
//  StatsDashboardContent.swift
//  StatsFeature
//
//  Created by Vladimir Gusev on 10.08.2026.
//

import SwiftUI
import Theme
import UI
import StatsCharts
import AnkiKit

struct StatsDashboardContent: View {

    enum State {
        case loading
        case loaded(GraphsSnapshot)
        case failed(String)
    }

    let state: State
    let period: StatsPeriod
    let selectedDeck: DeckInfo?
    let topLevelDecks: [DeckInfo]
    let onSelectDeck: (DeckInfo?) -> Void
    let onSelectPeriod: (StatsPeriod) -> Void
    let onRetry: () -> Void
    let streak: StreakSummary?
    let isRefreshing: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AmgiSpacing.lg) {
                filters

                if let streak {
                    StreakCard(streak: streak.days, comparison: streak.comparison)
                }

                switch state {
                case .loading:
                    ProgressView("Loading statistics...").padding(.top, 40)
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't Load Stats", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { onRetry() }
                    }
                case .loaded(let graphs):
                    charts(graphs)
                        .opacity(isRefreshing ? 0.4 : 1)
                        .overlay(alignment: .top) {
                            if isRefreshing { ProgressView().padding(.top, 40) }
                        }
                        .animation(AmgiMotion.standard, value: isRefreshing)
                }
            }
            .padding(AmgiSpacing.lg)
        }
    }

    // MARK: - Filters

    private var filters: some View {
        HStack(spacing: AmgiSpacing.md) {
            deckMenu
            periodMenu
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deckMenu: some View {
        Menu {
            Button { onSelectDeck(nil) } label: {
                if selectedDeck == nil { Label("Whole Collection", systemImage: "checkmark") }
                else { Text("Whole Collection") }
            }
            Divider()
            ForEach(topLevelDecks) { deck in
                Button { onSelectDeck(deck) } label: {
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
        .accessibilityLabel("Deck filter")
        .accessibilityValue(selectedDeck?.name ?? "Whole collection")
    }

    private var periodMenu: some View {
        Menu {
            ForEach(StatsPeriod.allCases, id: \.self) { p in
                Button { onSelectPeriod(p) } label: {
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
        .accessibilityLabel("Time period")
        .accessibilityValue(period.rawValue)
    }

    private func filterCapsule(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .amgiFont(.caption)
                .accessibilityHidden(true)
            Text(label)
                .fontWeight(.medium)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8))
                .accessibilityHidden(true)
        }
        .amgiFont(.body)
        .amgiCapsuleControl()
    }

    // MARK: - Charts

    @ViewBuilder
    private func charts(_ graphs: GraphsSnapshot) -> some View {
        StatsChartStack(graphs: graphs, period: period)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Loaded") {
    StatsDashboardContent(
        state: .loaded(.sample), period: .month, selectedDeck: nil,
        topLevelDecks: [], onSelectDeck: { _ in }, onSelectPeriod: { _ in }, onRetry: {},
        streak: StreakSummary(days: 36, comparison: 4), isRefreshing: false
    )
}

#Preview("Refreshing") {
    StatsDashboardContent(
        state: .loaded(.sample), period: .year, selectedDeck: nil,
        topLevelDecks: [], onSelectDeck: { _ in }, onSelectPeriod: { _ in }, onRetry: {},
        streak: StreakSummary(days: 3, comparison: -7), isRefreshing: true
    )
}

#Preview("Loading") {
    StatsDashboardContent(
        state: .loading, period: .month, selectedDeck: nil,
        topLevelDecks: [], onSelectDeck: { _ in }, onSelectPeriod: { _ in }, onRetry: {},
        streak: nil, isRefreshing: false
    )
}

#Preview("Failed") {
    StatsDashboardContent(
        state: .failed("The collection is locked."), period: .month,
        selectedDeck: nil, topLevelDecks: [], onSelectDeck: { _ in }, onSelectPeriod: { _ in }, onRetry: {},
        streak: nil, isRefreshing: false
    )
}
#endif
