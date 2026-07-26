import AnkiBackend
import AnkiKit
import AnkiProtoBridge
public import Dependencies
import Foundation
import Logging

private let logger = Logger(label: "com.amgiapp.notetypes.client")

extension NotetypesClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend

        return Self(
            listAll: {
                try backend.invoke(.notetypeNames)
            },
            get: { id in
                try backend.invoke(.notetype(for: id))
            },
            update: { notetype in
                try backend.invoke(.updateNotetype(notetype))
                logger.info("Notetype updated: id=\(notetype.id.rawValue)")
            },
            remove: { id in
                try backend.invoke(.removeNotetype(id: id))
                logger.info("Notetype removed: id=\(id.rawValue)")
            }
        )
    }()
}
