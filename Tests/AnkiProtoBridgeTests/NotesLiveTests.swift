//
//  NotesLiveTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

@Suite struct NotesLiveTests {
    private static let separator = "\u{1f}"

    private func addBasicNote(
        _ backend: AnkiBackend, front: String, back: String
    ) throws -> NoteID {
        let names = try backend.invoke(.notetypeNames)
        let basic = try #require(names.first { $0.name == "Basic" })
        var template = try backend.invoke(.newNote(notetypeId: basic.id))
        template.fields[0] = front
        template.fields[1] = back
        try backend.invoke(.addNote(template: template, deckId: DeckID(1)))

        let ids = try backend.invoke(.searchNoteIds(query: "\"\(front)\""))
        return try #require(ids.first)
    }

    @Test func getNote_reflectsWhatAddNoteWrote() throws {
        try withScratchCollection("notes-get") { backend, _ in
            let id = try addBasicNote(backend, front: "sōkō", back: "走行")

            let note = try backend.invoke(.getNote(id: id))
            #expect(note.id == id)
            #expect(note.flds == "sōkō\(Self.separator)走行")
            #expect(note.sfld == "sōkō")
            #expect(note.tags.isEmpty)
        }
    }

    @Test func addNote_carriesTheBackendGuid() throws {
        try withScratchCollection("notes-guid") { backend, _ in
            let first = try backend.invoke(.getNote(id: try addBasicNote(backend, front: "alpha", back: "one")))
            let second = try backend.invoke(.getNote(id: try addBasicNote(backend, front: "beta", back: "two")))

            #expect(!first.guid.isEmpty)
            #expect(!second.guid.isEmpty)
            #expect(first.guid != second.guid, "two notes must not share a guid")

            var edited = first
            edited.flds = "alpha\(Self.separator)edited"
            try backend.invoke(.updateNote(edited))
            #expect(try backend.invoke(.getNote(id: first.id)).guid == first.guid)
        }
    }

    @Test func searchNoteIds_narrowsAndWidens() throws {
        try withScratchCollection("notes-search") { backend, _ in
            _ = try addBasicNote(backend, front: "alpha", back: "one")
            _ = try addBasicNote(backend, front: "beta", back: "two")

            #expect(try backend.invoke(.searchNoteIds(query: "alpha")).count == 1)
            #expect(try backend.invoke(.searchNoteIds(query: "beta")).count == 1)
            #expect(try backend.invoke(.searchNoteIds(query: "deck:Default")).count == 2)
            #expect(try backend.invoke(.searchNoteIds(query: "nothingmatchesthis")).isEmpty)
        }
    }

    @Test func findAndReplace_scopesByNotesAndFieldAndUndoes() throws {
        try withScratchCollection("notes-find-replace") { backend, _ in
            let a = try addBasicNote(backend, front: "cat sat", back: "cat")
            let b = try addBasicNote(backend, front: "cat ran", back: "cat")
            #expect(try backend.invoke(.fieldNamesForNotes(noteIds: [a])).sorted() == ["Back", "Front"])

            let selected = try backend.invoke(.findAndReplace(
                noteIds: [a], search: "cat", replacement: "dog",
                regex: false, matchCase: false, fieldName: "Front"
            ))
            #expect(selected == 1)
            #expect(try backend.invoke(.getNote(id: a)).flds == "dog sat\(Self.separator)cat")
            #expect(try backend.invoke(.getNote(id: b)).flds == "cat ran\(Self.separator)cat")

            try backend.invoke(.undoLastAction)
            #expect(try backend.invoke(.getNote(id: a)).flds == "cat sat\(Self.separator)cat")

            let whole = try backend.invoke(.findAndReplace(
                noteIds: [], search: "CAT", replacement: "dog",
                regex: false, matchCase: true, fieldName: ""
            ))
            #expect(whole == 0, "match case must skip lowercase text")

            let regex = try backend.invoke(.findAndReplace(
                noteIds: [], search: "c.t", replacement: "dog",
                regex: true, matchCase: false, fieldName: ""
            ))
            #expect(regex == 2)
            #expect(try backend.invoke(.getNote(id: b)).flds == "dog ran\(Self.separator)dog")
        }
    }

    @Test func findAndReplace_literalDollarReplacementWithEscape() throws {
        try withScratchCollection("notes-find-replace-dollar") { backend, _ in
            let id = try addBasicNote(backend, front: "price", back: "x")
            _ = try backend.invoke(.findAndReplace(
                noteIds: [id], search: "price", replacement: "$$5",
                regex: false, matchCase: false, fieldName: "Front"
            ))
            #expect(try backend.invoke(.getNote(id: id)).flds == "$5\(Self.separator)x")
        }
    }

    @Test func findAndReplace_invalidRegexThrows() throws {
        try withScratchCollection("notes-find-replace-bad") { backend, _ in
            _ = try addBasicNote(backend, front: "cat", back: "x")
            #expect {
                try backend.invoke(.findAndReplace(
                    noteIds: [], search: "(", replacement: "", regex: true, matchCase: false, fieldName: ""
                ))
            } throws: { error in
                (error as? BackendError)?.message.hasPrefix("<pre>") == true
            }
        }
    }

    @Test func updateNote_thenRemoveNote() throws {
        try withScratchCollection("notes-update") { backend, _ in
            let id = try addBasicNote(backend, front: "before", back: "back")

            var note = try backend.invoke(.getNote(id: id))
            note.flds = "after\(Self.separator)back"
            note.tags = "probed"
            try backend.invoke(.updateNote(note))

            let reloaded = try backend.invoke(.getNote(id: id))
            #expect(reloaded.flds == "after\(Self.separator)back")
            #expect(reloaded.sfld == "after", "the backend recomputes sfld from field 0")
            #expect(reloaded.tags.contains("probed"))
            #expect(try backend.invoke(.searchNoteIds(query: "after")).count == 1)

            try backend.invoke(.removeNote(id: id))
            #expect(try backend.invoke(.searchNoteIds(query: "after")).isEmpty)
        }
    }
}
