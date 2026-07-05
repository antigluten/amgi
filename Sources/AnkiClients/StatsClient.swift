public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct StatsClient: Sendable {
    public var fetchGraphs: @Sendable (_ search: String, _ days: Int) async throws -> GraphsSnapshot
}

extension StatsClient: TestDependencyKey {
    public static let testValue = StatsClient()
}

extension DependencyValues {
    public var statsClient: StatsClient {
        get { self[StatsClient.self] }
        set { self[StatsClient.self] = newValue }
    }
}
