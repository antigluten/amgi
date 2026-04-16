import AnkiBackend
import AnkiProto
public import Dependencies
import DependenciesMacros
public import Foundation
import SwiftProtobuf

@DependencyClient
public struct StatsService: Sendable {
    /// Returns serialized Anki_Stats_GraphsResponse bytes for consumption by the stats renderer.
    public var fetchGraphs: @Sendable (_ search: String, _ days: UInt32) throws -> Data
}

extension StatsService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            fetchGraphs: { search, days in
                var req = Anki_Stats_GraphsRequest()
                req.search = search
                req.days = days
                let response: Anki_Stats_GraphsResponse = try backend.invoke(
                    service: AnkiBackend.Service.stats,
                    method: AnkiBackend.StatsMethod.graphs,
                    request: req
                )
                return try response.serializedData()
            }
        )
    }()
}

extension StatsService: TestDependencyKey {
    public static let testValue = StatsService()
}

extension DependencyValues {
    public var statsService: StatsService {
        get { self[StatsService.self] }
        set { self[StatsService.self] = newValue }
    }
}
