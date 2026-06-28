import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// FSRS simulation I/O for the simulator sheet. Owns the `deckClient`
/// dependency plus the run flag and result rows so the view carries no
/// `@Dependency`; the editable simulation context and the days/additional
/// inputs stay on the view and are passed into `run`.
@Observable
@MainActor
final class FsrsSimulatorModel {
    var isRunning = false
    var summary: [(label: String, value: String)] = []
    var workloadRows: [(label: String, value: String)] = []
    var errorMessage: String?

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient

    func run(context: FsrsSimulatorContext, daysToSimulate: Int, additionalCards: Int) async {
        isRunning = true
        defer { isRunning = false }
        errorMessage = nil

        let request = FsrsSimulationRequest(
            weights: FsrsWeights(context.weights),
            desiredRetention: Float(context.desiredRetentionPercent / 100),
            additionalCards: max(0, additionalCards),
            daysToSimulate: max(1, daysToSimulate),
            newLimit: max(0, context.newCardsPerDay),
            reviewLimit: max(0, context.reviewsPerDay),
            maxIntervalDays: max(1, context.maxIntervalDays),
            search: context.search,
            newCardsIgnoreReviewLimit: context.ignoreNewLimit,
            historicalRetention: Float(context.historicalRetentionPercent / 100),
            learningStepCount: context.learningStepCount,
            relearningStepCount: context.relearningStepCount,
            suspendAfterLapseCount: context.suspendLeeches ? max(1, context.leechThreshold) : nil
        )

        do {
            switch context.mode {
            case .review:
                let result = try deckClient.simulateFsrsReview(request)
                let totalNew = result.dailyNewCount.reduce(0, +)
                let totalReview = result.dailyReviewCount.reduce(0, +)
                let totalTime = result.dailyTimeCost.reduce(0, +)
                let memorized = result.accumulatedKnowledge.last ?? 0
                let days = max(result.dailyReviewCount.count, 1)
                summary = [
                    ("Total new", "\(totalNew)"),
                    ("Total reviews", "\(totalReview)"),
                    ("Avg reviews/day", String(format: "%.1f", Double(totalReview) / Double(days))),
                    ("Total time (s)", String(format: "%.1f", Double(totalTime))),
                    ("Memorized (end)", String(format: "%.1f", Double(memorized)))
                ]
                workloadRows = []
            case .workload:
                let result = try deckClient.simulateFsrsWorkload(request)
                let sorted = result.cost.keys.sorted()
                workloadRows = sorted.map { retention in
                    let cost = result.cost[retention] ?? 0
                    let count = result.reviewCount[retention] ?? 0
                    return (
                        "\(retention)%",
                        String(format: "cost %.2f · reviews %d", Double(cost), count)
                    )
                }
                summary = [("Points", "\(workloadRows.count)")]
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
