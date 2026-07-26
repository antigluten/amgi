import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto
private import SwiftProtobuf

@Suite struct NotesRequestsTests {
    // MARK: - getNote

    @Test func getNote_dispatches_to_notes_service() {
        let envelope: Request<NoteRecord> = .getNote(id: NoteID(7))
        #expect(envelope.serviceId == ServiceID.notes)
        #expect(envelope.methodId == NotesMethod.getNote)
    }

    @Test func getNote_encodes_nid() throws {
        let envelope: Request<NoteRecord> = .getNote(id: NoteID(42))
        let proto = try Anki_Notes_NoteId(serializedBytes: envelope.body)
        #expect(proto.nid == 42)
    }

    @Test func getNote_decodes_into_NoteRecord_with_joined_fields() throws {
        var note = Anki_Notes_Note()
        note.id = 1001
        note.guid = "abc123"
        note.notetypeID = 5
        note.mtimeSecs = 999
        note.usn = -1
        note.tags = ["k-vocab", "ch1"]
        note.fields = ["front", "back", "extra"]
        let bytes = try note.serializedData()

        let envelope: Request<NoteRecord> = .getNote(id: NoteID(1001))
        let record = try envelope.decode(bytes)
        #expect(record.id == NoteID(1001))
        #expect(record.guid == "abc123")
        #expect(record.mid == NotetypeID(5))
        #expect(record.mod == 999)
        #expect(record.tags == "k-vocab ch1")
        #expect(record.flds == "front\u{1f}back\u{1f}extra")
        #expect(record.sfld == "front")
    }

    // MARK: - newNote

    @Test func newNote_dispatches_and_encodes_notetype_id() throws {
        let envelope: Request<NewNoteTemplate> = .newNote(notetypeId: NotetypeID(33))
        #expect(envelope.serviceId == ServiceID.notes)
        #expect(envelope.methodId == NotesMethod.newNote)
        let proto = try Anki_Notetypes_NotetypeId(serializedBytes: envelope.body)
        #expect(proto.ntid == 33)
    }

    @Test func newNote_decodes_field_count_from_response() throws {
        var note = Anki_Notes_Note()
        note.fields = ["", "", ""]
        let bytes = try note.serializedData()

        let envelope: Request<NewNoteTemplate> = .newNote(notetypeId: NotetypeID(33))
        let template = try envelope.decode(bytes)
        #expect(template.notetypeId == NotetypeID(33))
        #expect(template.fields.count == 3)
        #expect(template.fields.allSatisfy { $0.isEmpty })
    }

    // MARK: - addNote

    @Test func addNote_dispatches_and_encodes_note_plus_deck() throws {
        let template = NewNoteTemplate(notetypeId: NotetypeID(5), fields: ["q", "a"])
        let envelope: Request<Void> = .addNote(template: template, deckId: DeckID(10))
        #expect(envelope.serviceId == ServiceID.notes)
        #expect(envelope.methodId == NotesMethod.addNote)
        let proto = try Anki_Notes_AddNoteRequest(serializedBytes: envelope.body)
        #expect(proto.deckID == 10)
        #expect(proto.note.notetypeID == 5)
        #expect(proto.note.fields == ["q", "a"])
    }

    // MARK: - updateNote

    @Test func updateNote_dispatches_and_splits_flds_back_into_fields() throws {
        let record = NoteRecord(
            id: NoteID(7), guid: "g", mid: NotetypeID(2), mod: 0, usn: -1,
            tags: "alpha beta",
            flds: "front\u{1f}back\u{1f}extra",
            sfld: "front", csum: 0
        )
        let envelope: Request<Void> = .updateNote(record)
        #expect(envelope.serviceId == ServiceID.notes)
        #expect(envelope.methodId == NotesMethod.updateNotes)
        let proto = try Anki_Notes_UpdateNotesRequest(serializedBytes: envelope.body)
        #expect(proto.notes.count == 1)
        #expect(proto.notes.first?.id == 7)
        #expect(proto.notes.first?.notetypeID == 2)
        #expect(proto.notes.first?.fields == ["front", "back", "extra"])
        #expect(proto.notes.first?.tags == ["alpha", "beta"])
    }

    @Test func updateNote_preserves_empty_fields() throws {
        let record = NoteRecord(
            id: NoteID(1), guid: "g", mid: NotetypeID(1), mod: 0,
            tags: "", flds: "front\u{1f}\u{1f}extra",
            sfld: "front", csum: 0
        )
        let envelope: Request<Void> = .updateNote(record)
        let proto = try Anki_Notes_UpdateNotesRequest(serializedBytes: envelope.body)
        #expect(proto.notes.first?.fields == ["front", "", "extra"])
    }

    // MARK: - removeNote

    @Test func removeNote_dispatches_and_encodes_id() throws {
        let envelope: Request<Void> = .removeNote(id: NoteID(99))
        #expect(envelope.serviceId == ServiceID.notes)
        #expect(envelope.methodId == NotesMethod.removeNotes)
        let proto = try Anki_Notes_RemoveNotesRequest(serializedBytes: envelope.body)
        #expect(proto.noteIds == [99])
    }

    // MARK: - searchNoteIds

    @Test func searchNoteIds_dispatches_to_search_service() {
        let envelope: Request<[NoteID]> = .searchNoteIds(query: "deck:Korean")
        #expect(envelope.serviceId == ServiceID.search)
        #expect(envelope.methodId == SearchMethod.searchNotes)
    }

    @Test func searchNoteIds_rewrites_empty_query_to_deck_glob() throws {
        let envelope: Request<[NoteID]> = .searchNoteIds(query: "")
        let proto = try Anki_Search_SearchRequest(serializedBytes: envelope.body)
        #expect(proto.search == "deck:*")
    }

    @Test func searchNoteIds_passes_non_empty_query_through() throws {
        let envelope: Request<[NoteID]> = .searchNoteIds(query: "tag:vocab")
        let proto = try Anki_Search_SearchRequest(serializedBytes: envelope.body)
        #expect(proto.search == "tag:vocab")
    }

    @Test func searchNoteIds_decodes_ids_in_order() throws {
        var resp = Anki_Search_SearchResponse()
        resp.ids = [10, 20, 30]
        let bytes = try resp.serializedData()
        let envelope: Request<[NoteID]> = .searchNoteIds(query: "")
        #expect(try envelope.decode(bytes) == [NoteID(10), NoteID(20), NoteID(30)])
    }
}
