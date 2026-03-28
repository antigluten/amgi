import AnkiKit
import AnkiBackend
import AnkiProto
public import Dependencies
import DependenciesMacros

extension NoteClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend

        return Self(
            fetch: { noteId in
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
                    sfld: note.fields.first ?? "", csum: 0,
                    flags: 0
                )
            },
            search: { query, limit in
                var req = Anki_Search_SearchRequest()
                req.search = query.isEmpty ? "deck:*" : query
                let response: Anki_Search_SearchResponse = try backend.invoke(
                    service: AnkiBackend.Service.search,
                    method: AnkiBackend.SearchMethod.searchNotes,
                    request: req
                )
                let ids = Array(response.ids.prefix(limit ?? 5000))

                // Fetch in batches for speed — each RPC has overhead,
                // but there's no batch API. Fetch first page fully,
                // return stubs for the rest (BrowseView fetches on demand).
                let firstPageSize = min(ids.count, 50)
                var results: [NoteRecord] = []
                results.reserveCapacity(ids.count)

                // Fetch first page with full details
                for nid in ids.prefix(firstPageSize) {
                    var r = Anki_Notes_NoteId()
                    r.nid = nid
                    if let note = try? backend.invoke(
                        service: AnkiBackend.Service.notes,
                        method: AnkiBackend.NotesMethod.getNote,
                        request: r
                    ) as Anki_Notes_Note {
                        results.append(NoteRecord(
                            id: note.id, guid: note.guid, mid: note.notetypeID,
                            mod: Int64(note.mtimeSecs), usn: note.usn,
                            tags: note.tags.joined(separator: " "),
                            flds: note.fields.joined(separator: "\u{1f}"),
                            sfld: note.fields.first ?? "", csum: 0,
                            flags: 0
                        ))
                    }
                }

                // Return stubs for remaining (ID + placeholder sfld)
                for nid in ids.dropFirst(firstPageSize) {
                    results.append(NoteRecord(
                        id: nid, guid: "", mid: 0, mod: 0, usn: 0,
                        tags: "", flds: "", sfld: "Loading...", csum: 0, flags: 0
                    ))
                }

                return results
            },
            save: { note in
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
            delete: { noteId in
                var req = Anki_Notes_RemoveNotesRequest()
                req.noteIds = [noteId]
                try backend.callVoid(
                    service: AnkiBackend.Service.notes,
                    method: 3, // removeNotes
                    request: req
                )
            }
        )
    }()
}
