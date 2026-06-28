import AnkiBackend
import AnkiProtoBridge
public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct StatsService: Sendable {
    /// Fetches the full graphs payload (every chart series the dashboard
    /// needs) for the supplied search filter and lookback window.
    public var fetchGraphs: @Sendable (_ search: String, _ days: Int) throws -> GraphsSnapshot
}

extension StatsService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            fetchGraphs: { search, days in
                try backend.invoke(.graphs(search: search, days: days))
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
