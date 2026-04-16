import AnkiKit
import AnkiServices
public import Dependencies
import DependenciesMacros

extension NoteClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.notesService) var notes

        return Self(
            fetch: { noteId in
                try notes.getNote(noteId)
            },
            search: { query, limit in
                let ids = try notes.searchNoteIds(query)
                let bounded = Array(ids.prefix(limit ?? 5000))

                let firstPageSize = min(bounded.count, 50)
                var results: [NoteRecord] = []
                results.reserveCapacity(bounded.count)

                for nid in bounded.prefix(firstPageSize) {
                    if let note = try? notes.getNote(nid) {
                        results.append(note)
                    }
                }

                for nid in bounded.dropFirst(firstPageSize) {
                    results.append(NoteRecord(
                        id: nid, guid: "", mid: 0, mod: 0,
                        tags: "", flds: "", sfld: "Loading...", csum: 0
                    ))
                }

                return results
            },
            save: { note in
                try notes.saveNote(note)
            },
            delete: { noteId in
                try notes.deleteNote(noteId)
            }
        )
    }()
}
