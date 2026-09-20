//
//  StatsChartStack.swift
//  StatsCharts
//
//  Created by Vladimir Gusev on 20.08.2026.
//

public import SwiftUI
public import AnkiKit

public struct StatsChartStack: View {
    private let graphs: GraphsSnapshot
    private let period: StatsPeriod
    private let isCompact: Bool

    public init(graphs: GraphsSnapshot, period: StatsPeriod, isCompact: Bool = false) {
        self.graphs = graphs
        self.period = period
        self.isCompact = isCompact
    }

    public var body: some View {
        PeriodStatsCard(period: period, today: graphs.today, reviews: graphs.reviews)
        FutureDueChart(futureDue: graphs.futureDue, period: period)
        if !isCompact {
            HeatmapChartOptimized(reviews: graphs.reviews)
        }
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
