public import Foundation
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct MediaClient: Sendable {
    public var localURL: @Sendable (_ filename: String) -> URL? = { _ in nil }
    public var save: @Sendable (_ data: Data, _ filename: String) throws -> Void
    public var delete: @Sendable (_ filename: String) throws -> Void
}

extension MediaClient: TestDependencyKey {
    public static let testValue = MediaClient()
}

extension DependencyValues {
    public var mediaClient: MediaClient {
        get { self[MediaClient.self] }
        set { self[MediaClient.self] = newValue }
    }
}
