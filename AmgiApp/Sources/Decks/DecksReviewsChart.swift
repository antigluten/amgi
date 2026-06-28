import AmgiTheme
import AnkiClients
import AnkiProto
import Dependencies
import SwiftProtobuf
import SwiftUI

/// Compact reviews heatmap shown above the deck list. Reuses the same
/// `HeatmapChartOptimized` component the Stats dashboard renders, in
/// `compactHeight` mode so the cells shrink to fit a header role.
///
/// Loads `Anki_Stats_GraphsResponse` once on appear; deck-list pull-
/// to-refresh re-renders the parent (`.id(refreshID)`) which re-runs
/// the task.
struct DecksReviewsChart: View {
    var days: Int = 365

    @Dependency(\.statsClient) private var statsClient
    @State private var reviews: Anki_Stats_GraphsResponse.ReviewCountsAndTimes?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 200)
            } else if let reviews {
                // Full-size heatmap — same call shape as StatsDashboardView
                // so the visual matches what the Stats tab renders.
                HeatmapChartOptimized(reviews: reviews)
            } else {
                Text(errorMessage ?? "No reviews yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 200)
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            let data = try statsClient.fetchGraphs("", UInt32(days))
            let response = try Anki_Stats_GraphsResponse(serializedBytes: data)
            reviews = response.reviews
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            reviews = nil
        }
        isLoading = false
    }
}
