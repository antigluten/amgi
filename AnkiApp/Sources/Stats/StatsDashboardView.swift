import SwiftUI
import AnkiKit
import AnkiClients
import Dependencies

struct StatsDashboardView: View {
    @Dependency(\.statsClient) var statsClient

    @State private var todayStats: TodayStats = .init()
    @State private var cardBreakdown: CardStateBreakdown = .init()
    @State private var heatmapData: [DayCount] = []
    @State private var retentionData: Double = 0
    @State private var forecastData: [DayCount] = []
    @State private var hourlyData: [HourCount] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading {
                    ProgressView().padding(.top, 40)
                } else {
                    TodayStatsCard(stats: todayStats)
                    CardStateChart(breakdown: cardBreakdown)
                    HeatmapChart(data: heatmapData)
                    RetentionChart(rate: retentionData)
                    ForecastChart(data: forecastData)
                    HourlyChart(data: hourlyData)
                }
            }
            .padding()
        }
        .navigationTitle("Statistics")
        .task { await loadStats() }
        .refreshable { await loadStats() }
    }

    private func loadStats() async {
        do {
            todayStats = try statsClient.todayStats()
            cardBreakdown = try statsClient.cardStates()
            heatmapData = try statsClient.heatmap(365)
            retentionData = try statsClient.retentionRate(30)
            forecastData = try statsClient.forecast(30)
            hourlyData = try statsClient.hourlyBreakdown()
        } catch {}
        isLoading = false
    }
}
