import AnkiBackend
import AnkiProto
public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct NotetypesService: Sendable {
    public var getNotetypeNames: @Sendable () throws -> [(id: Int64, name: String)]
    public var getNotetype: @Sendable (_ id: Int64) throws -> NotetypeInfo
    /// Returns full per-field info (name, ordinal, font, size) for a notetype.
    /// Used by typed-answer rendering in ReviewSession.
    public var getNotetypeFields: @Sendable (_ id: Int64) throws -> [NotetypeFieldInfo]
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
            },
            getNotetypeFields: { id in
                var req = Anki_Notetypes_NotetypeId()
                req.ntid = id
                let notetype: Anki_Notetypes_Notetype = try backend.invoke(
                    service: AnkiBackend.Service.notetypes,
                    method: AnkiBackend.NotetypesMethod.getNotetype,
                    request: req
                )
                return notetype.fields.map { field in
                    NotetypeFieldInfo(
                        name: field.name,
                        ordinal: Int(field.ord.val),
                        fontName: field.config.fontName.isEmpty ? "-apple-system" : field.config.fontName,
                        fontSize: field.config.fontSize == 0 ? 18 : Int(field.config.fontSize)
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
