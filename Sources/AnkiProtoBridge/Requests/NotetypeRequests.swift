import Foundation
public import AnkiBackend
public import AnkiKit
import AnkiProto
import SwiftProtobuf

// MARK: - getNotetypeNames

extension Request where Response == [NotetypeNameId] {
    /// Lists every notetype as `(id, name)` — the lightweight listing
    /// used by pickers and the templates browser.
    public static var notetypeNames: Self {
        .empty(
            serviceId: ServiceID.notetypes,
            methodId: NotetypesMethod.getNotetypeNames,
            decode: { bytes in
                let resp = try Anki_Notetypes_NotetypeNames(serializedBytes: bytes)
                return resp.entries.map(NotetypeNameId.init)
            }
        )
    }
}

// MARK: - getNotetype

extension Request where Response == Notetype {
    /// Fetches the full notetype (config, fields, templates) by id.
    public static func notetype(for id: NotetypeID) -> Self {
        .decoded(
            serviceId: ServiceID.notetypes,
            methodId: NotetypesMethod.getNotetype,
            encode: {
                var req = Anki_Notetypes_NotetypeId()
                req.ntid = id.rawValue
                return try req.serializedData()
            }
        )
    }
}

// MARK: - updateNotetype / removeNotetype

extension Request where Response == Void {
    /// Persists a modified notetype.
    public static func updateNotetype(_ notetype: Notetype) -> Self {
        Self(
            serviceId: ServiceID.notetypes,
            methodId: NotetypesMethod.updateNotetype,
            encode: { try notetype.toProto().serializedData() },
            decode: { _ in () }
        )
    }

    /// Removes a notetype and every card based on it.
    public static func removeNotetype(id: NotetypeID) -> Self {
        Self(
            serviceId: ServiceID.notetypes,
            methodId: NotetypesMethod.removeNotetype,
            encode: {
                var req = Anki_Notetypes_NotetypeId()
                req.ntid = id.rawValue
                return try req.serializedData()
            },
            decode: { _ in () }
        )
    }
}
