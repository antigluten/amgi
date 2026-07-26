#if DEBUG
import AnkiKit
import Dependencies

extension StatsClient {
    /// Deterministic in-memory client used by SwiftUI `#Preview` blocks.
    /// Returns a fully-populated `GraphsSnapshot` so every chart renders.
    public static let previewValue = StatsClient(
        fetchGraphs: { _, _ in
            GraphsSnapshot.sample
        }
    )
}
#endif
