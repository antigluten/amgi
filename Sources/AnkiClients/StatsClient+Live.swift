import AnkiServices
public import Dependencies
import DependenciesMacros

extension StatsClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.statsService) var stats

        return Self(
            fetchGraphs: { search, days in
                try stats.fetchGraphs(search, days)
            }
        )
    }()
}
