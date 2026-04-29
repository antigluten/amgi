import AnkiBackend
import AnkiProto
public import Dependencies
import Foundation
import Logging
import SwiftProtobuf

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
                guard let folder = backend.currentMediaFolderPath else { return }
                let url = URL(fileURLWithPath: folder).appendingPathComponent(filename)
                try data.write(to: url)
            },
            delete: { filename in
                guard let folder = backend.currentMediaFolderPath else { return }
                let url = URL(fileURLWithPath: folder).appendingPathComponent(filename)
                try FileManager.default.removeItem(at: url)
            },
            checkMedia: {
                let resp: Anki_Media_CheckMediaResponse = try backend.invoke(
                    service: AnkiBackend.Service.media,
                    method: AnkiBackend.MediaMethod.checkMedia
                )
                return MediaCheckResult(
                    missing: resp.missing,
                    unused: resp.unused,
                    missingNoteIDs: resp.missingMediaNotes,
                    report: resp.report,
                    haveTrash: resp.haveTrash
                )
            },
            trashMediaFiles: { filenames in
                var req = Anki_Media_TrashMediaFilesRequest()
                req.fnames = filenames
                try backend.callVoid(
                    service: AnkiBackend.Service.media,
                    method: AnkiBackend.MediaMethod.trashMediaFiles,
                    request: req
                )
                logger.info("Moved \(filenames.count) media files to trash")
            },
            emptyTrash: {
                try backend.callVoid(
                    service: AnkiBackend.Service.media,
                    method: AnkiBackend.MediaMethod.emptyTrash
                )
                logger.info("Media trash emptied")
            },
            restoreTrash: {
                try backend.callVoid(
                    service: AnkiBackend.Service.media,
                    method: AnkiBackend.MediaMethod.restoreTrash
                )
                logger.info("Media trash restored")
            }
        )
    }()
}
