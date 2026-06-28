public import AnkiKit
public import Dependencies
import DependenciesMacros
public import Foundation

@DependencyClient
public struct SyncClient: Sendable {
    public var sync: @Sendable () async throws -> SyncSummary
    public var fullSync: @Sendable (_ direction: SyncDirection) async throws -> Void
    public var syncMedia: @Sendable () async throws -> MediaSyncSummary
    public var lastSyncDate: @Sendable () -> Date? = { nil }
}

extension SyncClient: TestDependencyKey {
    public static let testValue = SyncClient()
}

extension DependencyValues {
    public var syncClient: SyncClient {
        get { self[SyncClient.self] }
        set { self[SyncClient.self] = newValue }
    }
}
