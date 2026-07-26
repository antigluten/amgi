import Foundation
public import AnkiBackend
public import AnkiKit
import AnkiProto
import SwiftProtobuf

// MARK: - checkMedia

extension Request where Response == MediaCheckResult {
    /// Runs the backend's media-check pass and returns the orphan/missing
    /// snapshot. No request body — the backend infers context from the
    /// open collection.
    public static var checkMedia: Self {
        .empty(
            serviceId: ServiceID.media,
            methodId: MediaMethod.checkMedia,
            decode: { bytes in
                let proto = try Anki_Media_CheckMediaResponse(serializedBytes: bytes)
                return MediaCheckResult(
                    missing: proto.missing,
                    unused: proto.unused,
                    missingNoteIDs: proto.missingMediaNotes.map { NoteID($0) },
                    report: proto.report,
                    haveTrash: proto.haveTrash
                )
            }
        )
    }
}

// MARK: - trash + restore (Void)

extension Request where Response == Void {
    /// Moves the named media files into the trash directory (recoverable
    /// until `emptyTrash` runs).
    public static func trashMediaFiles(filenames: [String]) -> Self {
        Self(
            serviceId: ServiceID.media,
            methodId: MediaMethod.trashMediaFiles,
            encode: {
                var proto = Anki_Media_TrashMediaFilesRequest()
                proto.fnames = filenames
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Permanently deletes everything currently in the media trash.
    public static var emptyMediaTrash: Self {
        .empty(
            serviceId: ServiceID.media,
            methodId: MediaMethod.emptyTrash,
            decode: { _ in () }
        )
    }

    /// Restores files in the media trash back into the active media folder.
    public static var restoreMediaTrash: Self {
        .empty(
            serviceId: ServiceID.media,
            methodId: MediaMethod.restoreTrash,
            decode: { _ in () }
        )
    }
}
