import Foundation
public import AnkiBackend
public import AnkiKit
import AnkiProto
import SwiftProtobuf

// MARK: - getNote

extension Request where Response == NoteRecord {
    /// Fetches a single note by id.
    public static func getNote(id: NoteID) -> Self {
        .decoded(
            serviceId: ServiceID.notes,
            methodId: NotesMethod.getNote,
            encode: {
                var proto = Anki_Notes_NoteId()
                proto.nid = id.rawValue
                return try proto.serializedData()
            }
        )
    }
}

// MARK: - newNote (template)

extension Request where Response == NewNoteTemplate {
    /// Returns a blank template for the given notetype with the correct
    /// field count. Used by add-note UI to allocate the input array.
    public static func newNote(notetypeId: NotetypeID) -> Self {
        Self(
            serviceId: ServiceID.notes,
            methodId: NotesMethod.newNote,
            encode: {
                var proto = Anki_Notetypes_NotetypeId()
                proto.ntid = notetypeId.rawValue
                return try proto.serializedData()
            },
            decode: { bytes in
                let note = try Anki_Notes_Note(serializedBytes: bytes)
                return NewNoteTemplate(
                    notetypeId: notetypeId,
                    fields: Array(repeating: "", count: note.fields.count)
                )
            }
        )
    }
}

// MARK: - addNote / updateNote / removeNote (Void)

extension Request where Response == Void {
    /// Adds a note built from `template` to `deckId`. The backend's
    /// returned change-record is discarded — callers refresh state via
    /// their own queries.
    public static func addNote(template: NewNoteTemplate, deckId: DeckID) -> Self {
        Self(
            serviceId: ServiceID.notes,
            methodId: NotesMethod.addNote,
            encode: {
                var note = Anki_Notes_Note()
                note.notetypeID = template.notetypeId.rawValue
                note.fields = template.fields
                note.tags = template.tags

                var proto = Anki_Notes_AddNoteRequest()
                proto.note = note
                proto.deckID = deckId.rawValue
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Persists field/tag edits on an existing note.
    public static func updateNote(_ note: NoteRecord) -> Self {
        Self(
            serviceId: ServiceID.notes,
            methodId: NotesMethod.updateNotes,
            encode: {
                var proto = Anki_Notes_UpdateNotesRequest()
                proto.notes = [Anki_Notes_Note(note)]
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Removes a single note (and its cards) by id.
    public static func removeNote(id: NoteID) -> Self {
        Self(
            serviceId: ServiceID.notes,
            methodId: NotesMethod.removeNotes,
            encode: {
                var proto = Anki_Notes_RemoveNotesRequest()
                proto.noteIds = [id.rawValue]
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }
}

// MARK: - searchNotes

extension Request where Response == [NoteID] {
    /// Runs a note search and returns the matching note ids in match order.
    /// An empty query is rewritten to `deck:*` to match the existing
    /// service-level behaviour.
    public static func searchNoteIds(query: String) -> Self {
        Self(
            serviceId: ServiceID.search,
            methodId: SearchMethod.searchNotes,
            encode: {
                var proto = Anki_Search_SearchRequest()
                proto.search = query.isEmpty ? "deck:*" : query
                return try proto.serializedData()
            },
            decode: { bytes in
                let resp = try Anki_Search_SearchResponse(serializedBytes: bytes)
                return resp.ids.map { NoteID($0) }
            }
        )
    }
}
