import AnkiBackend
import AnkiProto
public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct CollectionService: Sendable {
    public var checkDatabase: @Sendable () throws -> Void
    public var undoLast: @Sendable () throws -> Void
}

extension CollectionService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            checkDatabase: {
                try backend.checkDatabase()
            },
            undoLast: {
                try backend.callVoid(
                    service: AnkiBackend.Service.collectionOps,
                    method: AnkiBackend.CollectionOpsMethod.undo
                )
            }
        )
    }()
}

extension CollectionService: TestDependencyKey {
    public static let testValue = CollectionService()
}

extension DependencyValues {
    public var collectionService: CollectionService {
        get { self[CollectionService.self] }
        set { self[CollectionService.self] = newValue }
    }
}
