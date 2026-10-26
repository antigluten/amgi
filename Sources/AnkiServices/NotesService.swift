//
//  NotesService.swift
//  AnkiServices
//
//  Created by Vladimir Gusev on 01.04.2026.
//

import AnkiBackend
import AnkiProtoBridge
public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct NotesService: Sendable {
    public var getNote: @Sendable (_ noteId: NoteID) throws -> NoteRecord
    public var searchNoteIds: @Sendable (_ query: String) throws -> [NoteID]
    public var saveNote: @Sendable (_ note: NoteRecord) throws -> Void
    public var deleteNote: @Sendable (_ noteId: NoteID) throws -> Void
    public var newNote: @Sendable (_ notetypeId: NotetypeID) throws -> NewNoteTemplate
    public var addNote: @Sendable (_ template: NewNoteTemplate, _ deckId: DeckID) throws -> Void
    public var findDuplicates: @Sendable () throws -> [DuplicateGroup]
    public var fieldNamesForNotes: @Sendable (_ noteIds: [NoteID]) throws -> [String]
    public var findAndReplace: @Sendable (
        _ noteIds: [NoteID], _ search: String, _ replacement: String,
        _ regex: Bool, _ matchCase: Bool, _ fieldName: String
    ) throws -> Int
}

extension NotesService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            getNote: { noteId in
                try backend.invoke(.getNote(id: noteId))
            },
            searchNoteIds: { query in
                try backend.invoke(.searchNoteIds(query: query))
            },
            saveNote: { note in
                try backend.invoke(.updateNote(note))
            },
            deleteNote: { noteId in
                try backend.invoke(.removeNote(id: noteId))
            },
            newNote: { notetypeId in
                try backend.invoke(.newNote(notetypeId: notetypeId))
            },
            addNote: { template, deckId in
                try backend.invoke(.addNote(template: template, deckId: deckId))
            },
            findDuplicates: {
                try backend.invoke(.findDuplicates)
            },
            fieldNamesForNotes: { noteIds in
                try backend.invoke(.fieldNamesForNotes(noteIds: noteIds))
            },
            findAndReplace: { noteIds, search, replacement, regex, matchCase, fieldName in
                try backend.invoke(.findAndReplace(
                    noteIds: noteIds, search: search, replacement: replacement,
                    regex: regex, matchCase: matchCase, fieldName: fieldName
                ))
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
