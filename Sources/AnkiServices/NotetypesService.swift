import AnkiBackend
import AnkiProtoBridge
public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct NotetypesService: Sendable {
    public var getNotetypeNames: @Sendable () throws -> [(id: NotetypeID, name: String)]
    public var getNotetype: @Sendable (_ id: NotetypeID) throws -> NotetypeInfo
    /// Returns full per-field info (name, ordinal, font, size) for a notetype.
    /// Used by typed-answer rendering in ReviewSession.
    public var getNotetypeFields: @Sendable (_ id: NotetypeID) throws -> [NotetypeFieldInfo]
}

extension NotetypesService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            getNotetypeNames: {
                try backend.invoke(.notetypeNames).map { (id: $0.id, name: $0.name) }
            },
            getNotetype: { id in
                let notetype = try backend.invoke(.notetype(for: id))
                return NotetypeInfo(
                    id: notetype.id,
                    name: notetype.name,
                    fieldNames: notetype.fields.map(\.name)
                )
            },
            getNotetypeFields: { id in
                let notetype = try backend.invoke(.notetype(for: id))
                return notetype.fields.map { field in
                    NotetypeFieldInfo(
                        name: field.name,
                        ordinal: field.ord ?? 0,
                        fontName: field.config.fontName.isEmpty ? "-apple-system" : field.config.fontName,
                        fontSize: field.config.fontSize == 0 ? 18 : field.config.fontSize
                    )
                }
            }
        )
    }()
}

extension NotetypesService: TestDependencyKey {
    public static let testValue = NotetypesService()
}

extension DependencyValues {
    public var notetypesService: NotetypesService {
        get { self[NotetypesService.self] }
        set { self[NotetypesService.self] = newValue }
    }
}
