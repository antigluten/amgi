import AnkiBackend
import AnkiProto
public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct NotetypesService: Sendable {
    public var getNotetypeNames: @Sendable () throws -> [(id: Int64, name: String)]
    public var getNotetype: @Sendable (_ id: Int64) throws -> NotetypeInfo
}

extension NotetypesService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            getNotetypeNames: {
                let resp: Anki_Notetypes_NotetypeNames = try backend.invoke(
                    service: AnkiBackend.Service.notetypes,
                    method: AnkiBackend.NotetypesMethod.getNotetypeNames
                )
                return resp.entries.map { ($0.id, $0.name) }
            },
            getNotetype: { id in
                var req = Anki_Notetypes_NotetypeId()
                req.ntid = id
                let notetype: Anki_Notetypes_Notetype = try backend.invoke(
                    service: AnkiBackend.Service.notetypes,
                    method: AnkiBackend.NotetypesMethod.getNotetype,
                    request: req
                )
                return NotetypeInfo(
                    id: notetype.id,
                    name: notetype.name,
                    fieldNames: notetype.fields.map(\.name)
                )
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
