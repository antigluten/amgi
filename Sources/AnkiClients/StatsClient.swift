public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct StatsClient: Sendable {
    public var heatmap: @Sendable (_ days: Int) throws -> [DayCount]
    public var forecast: @Sendable (_ days: Int) throws -> [DayCount]
    public var retentionRate: @Sendable (_ days: Int) throws -> Double
    public var todayStats: @Sendable () throws -> TodayStats
    public var cardStates: @Sendable () throws -> CardStateBreakdown
    public var hourlyBreakdown: @Sendable () throws -> [HourCount]
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
