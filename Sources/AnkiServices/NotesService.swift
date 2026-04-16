import AnkiBackend
import AnkiProto
public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct NotesService: Sendable {
    public var getNote: @Sendable (_ noteId: Int64) throws -> NoteRecord
    public var searchNoteIds: @Sendable (_ query: String) throws -> [Int64]
    public var saveNote: @Sendable (_ note: NoteRecord) throws -> Void
    public var deleteNote: @Sendable (_ noteId: Int64) throws -> Void
    public var newNote: @Sendable (_ notetypeId: Int64) throws -> NewNoteTemplate
    public var addNote: @Sendable (_ template: NewNoteTemplate, _ deckId: Int64) throws -> Void
}

extension NotesService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            getNote: { noteId in
                var req = Anki_Notes_NoteId()
                req.nid = noteId
                let note: Anki_Notes_Note = try backend.invoke(
                    service: AnkiBackend.Service.notes,
                    method: AnkiBackend.NotesMethod.getNote,
                    request: req
                )
                return NoteRecord(
                    id: note.id, guid: note.guid, mid: note.notetypeID,
                    mod: Int64(note.mtimeSecs), usn: note.usn,
                    tags: note.tags.joined(separator: " "),
                    flds: note.fields.joined(separator: "\u{1f}"),
                    sfld: note.fields.first ?? "", csum: 0
                )
            },
            searchNoteIds: { query in
                var req = Anki_Search_SearchRequest()
                req.search = query.isEmpty ? "deck:*" : query
                let response: Anki_Search_SearchResponse = try backend.invoke(
                    service: AnkiBackend.Service.search,
                    method: AnkiBackend.SearchMethod.searchNotes,
                    request: req
                )
                return response.ids
            },
            saveNote: { note in
                var protoNote = Anki_Notes_Note()
                protoNote.id = note.id
                protoNote.notetypeID = note.mid
                protoNote.fields = note.flds
                    .split(separator: "\u{1f}", omittingEmptySubsequences: false)
                    .map(String.init)
                protoNote.tags = note.tags
                    .split(separator: " ")
                    .map(String.init)
                var req = Anki_Notes_UpdateNotesRequest()
                req.notes = [protoNote]
                try backend.callVoid(
                    service: AnkiBackend.Service.notes,
                    method: AnkiBackend.NotesMethod.updateNotes,
                    request: req
                )
            },
            deleteNote: { noteId in
                var req = Anki_Notes_RemoveNotesRequest()
                req.noteIds = [noteId]
                try backend.callVoid(
                    service: AnkiBackend.Service.notes,
                    method: AnkiBackend.NotesMethod.removeNotes,
                    request: req
                )
            },
            newNote: { notetypeId in
                var req = Anki_Notetypes_NotetypeId()
                req.ntid = notetypeId
                let note: Anki_Notes_Note = try backend.invoke(
                    service: AnkiBackend.Service.notes,
                    method: AnkiBackend.NotesMethod.newNote,
                    request: req
                )
                return NewNoteTemplate(
                    notetypeId: notetypeId,
                    fields: Array(repeating: "", count: note.fields.count)
                )
            },
            addNote: { template, deckId in
                var req = Anki_Notes_AddNoteRequest()
                var note = Anki_Notes_Note()
                note.notetypeID = template.notetypeId
                note.fields = template.fields
                note.tags = template.tags
                req.note = note
                req.deckID = deckId
                let _: Anki_Collection_OpChangesWithId = try backend.invoke(
                    service: AnkiBackend.Service.notes,
                    method: AnkiBackend.NotesMethod.addNote,
                    request: req
                )
            }
        )
    }()
}

extension NotesService: TestDependencyKey {
    public static let testValue = NotesService()
}

extension DependencyValues {
    public var notesService: NotesService {
        get { self[NotesService.self] }
        set { self[NotesService.self] = newValue }
    }
}
