import Foundation
public import AnkiBackend
public import AnkiKit
import AnkiProto
import SwiftProtobuf

extension Request where Response == GraphsSnapshot {
    /// Fetches the full graphs payload (every chart series the dashboard
    /// needs) for the supplied search filter and lookback window.
    ///
    /// - Parameters:
    ///   - search: backend search expression (`""` means whole collection).
    ///   - days: lookback in days. Wire field is `UInt32`.
    public static func graphs(search: String, days: Int) -> Self {
        .decoded(
            serviceId: ServiceID.stats,
            methodId: StatsMethod.graphs,
            encode: {
                var req = Anki_Stats_GraphsRequest()
                req.search = search
                req.days = UInt32(max(0, days))
                return try req.serializedData()
            }
        )
    }
}
