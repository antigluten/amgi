import AnkiBackend
import AnkiKit
import AnkiProtoBridge
public import Dependencies
import Foundation
import Logging

private let logger = Logger(label: "com.amgiapp.media.client")

extension MediaClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend

        return Self(
            localURL: { filename in
                guard let folder = backend.currentMediaFolderPath else { return nil }
                let url = URL(fileURLWithPath: folder).appendingPathComponent(filename)
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            },
            save: { data, filename in
                try await backendOffload {
                    guard let folder = backend.currentMediaFolderPath else { return }
                    let url = URL(fileURLWithPath: folder).appendingPathComponent(filename)
                    try data.write(to: url)
                }
            },
            delete: { filename in
                try await backendOffload {
                    guard let folder = backend.currentMediaFolderPath else { return }
                    let url = URL(fileURLWithPath: folder).appendingPathComponent(filename)
                    try FileManager.default.removeItem(at: url)
                }
            },
            checkMedia: {
                try await backend.invoke(.checkMedia)
            },
            trashMediaFiles: { filenames in
                try await backend.invoke(.trashMediaFiles(filenames: filenames))
                logger.info("Moved \(filenames.count) media files to trash")
            },
            emptyTrash: {
                try await backend.invoke(.emptyMediaTrash)
                logger.info("Media trash emptied")
            },
            restoreTrash: {
                try await backend.invoke(.restoreMediaTrash)
                logger.info("Media trash restored")
            }
        )
    }()
}
