import AnkiBackend
import AnkiProto
public import Dependencies
import Foundation
import Logging
import SwiftProtobuf

private let logger = Logger(label: "com.amgiapp.notetypes.client")

extension NotetypesClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend

        return Self(
            listAll: {
                let resp: Anki_Notetypes_NotetypeNames = try backend.invoke(
                    service: AnkiBackend.Service.notetypes,
                    method: AnkiBackend.NotetypesMethod.getNotetypeNames
                )
                return resp.entries
            },
            getRaw: { id in
                var req = Anki_Notetypes_NotetypeId()
                req.ntid = id
                let notetype: Anki_Notetypes_Notetype = try backend.invoke(
                    service: AnkiBackend.Service.notetypes,
                    method: AnkiBackend.NotetypesMethod.getNotetype,
                    request: req
                )
                return notetype
            },
            update: { notetype in
                try backend.callVoid(
                    service: AnkiBackend.Service.notetypes,
                    method: AnkiBackend.NotetypesMethod.updateNotetype,
                    request: notetype
                )
                logger.info("Notetype updated: id=\(notetype.id)")
            },
            remove: { id in
                var req = Anki_Notetypes_NotetypeId()
                req.ntid = id
                try backend.callVoid(
                    service: AnkiBackend.Service.notetypes,
                    method: AnkiBackend.NotetypesMethod.removeNotetype,
                    request: req
                )
                logger.info("Notetype removed: id=\(id)")
            }
        )
    }()
}
