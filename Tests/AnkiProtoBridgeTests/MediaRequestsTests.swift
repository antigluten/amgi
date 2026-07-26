import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto
private import SwiftProtobuf

@Suite struct MediaRequestsTests {
    @Test func checkMedia_dispatches_with_empty_body() throws {
        let envelope: Request<MediaCheckResult> = .checkMedia
        #expect(envelope.serviceId == ServiceID.media)
        #expect(envelope.methodId == MediaMethod.checkMedia)
        #expect(try envelope.body.isEmpty)
    }

    @Test func checkMedia_decodes_lists_and_flags() throws {
        var resp = Anki_Media_CheckMediaResponse()
        resp.unused = ["orphan1.png", "orphan2.png"]
        resp.missing = ["needed.mp3"]
        resp.missingMediaNotes = [100, 200]
        resp.report = "1 missing, 2 unused"
        resp.haveTrash = true
        let bytes = try resp.serializedData()

        let envelope: Request<MediaCheckResult> = .checkMedia
        let result = try envelope.decode(bytes)
        #expect(result.unused == ["orphan1.png", "orphan2.png"])
        #expect(result.missing == ["needed.mp3"])
        #expect(result.missingNoteIDs == [NoteID(100), NoteID(200)])
        #expect(result.report == "1 missing, 2 unused")
        #expect(result.haveTrash)
    }

    @Test func trashMediaFiles_dispatches_and_encodes_filenames() throws {
        let envelope: Request<Void> = .trashMediaFiles(filenames: ["a.png", "b.png"])
        #expect(envelope.serviceId == ServiceID.media)
        #expect(envelope.methodId == MediaMethod.trashMediaFiles)
        let proto = try Anki_Media_TrashMediaFilesRequest(serializedBytes: envelope.body)
        #expect(proto.fnames == ["a.png", "b.png"])
    }

    @Test func emptyMediaTrash_dispatches_with_empty_body() throws {
        let envelope: Request<Void> = .emptyMediaTrash
        #expect(envelope.serviceId == ServiceID.media)
        #expect(envelope.methodId == MediaMethod.emptyTrash)
        #expect(try envelope.body.isEmpty)
    }

    @Test func restoreMediaTrash_dispatches_with_empty_body() throws {
        let envelope: Request<Void> = .restoreMediaTrash
        #expect(envelope.serviceId == ServiceID.media)
        #expect(envelope.methodId == MediaMethod.restoreTrash)
        #expect(try envelope.body.isEmpty)
    }
}
