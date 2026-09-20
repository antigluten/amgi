//
//  TagsLiveTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

@Suite struct TagsLiveTests {
    private func addNote(_ backend: AnkiBackend, front: String, tags: [String]) throws -> NoteID {
        let names = try backend.invoke(.notetypeNames)
        let basic = try #require(names.first { $0.name == "Basic" })
        var template = try backend.invoke(.newNote(notetypeId: basic.id))
        template.fields[0] = front
        template.fields[1] = "back"
        template.tags = tags
        try backend.invoke(.addNote(template: template, deckId: DeckID(1)))
        return try #require(try backend.invoke(.searchNoteIds(query: "\"\(front)\"")).first)
    }

    @Test func addAndRemoveNoteTags() throws {
        try withScratchCollection("tags-note") { backend, _ in
            let id = try addNote(backend, front: "tagged", tags: [])
            #expect(try backend.invoke(.allTagPaths).isEmpty)

            try backend.invoke(.addNoteTags(noteIds: [id], tags: "jp::verb"))
            #expect(try backend.invoke(.getNote(id: id)).tags.contains("jp::verb"))
            #expect(try backend.invoke(.allTagPaths).contains("jp::verb"))

            try backend.invoke(.removeNoteTags(noteIds: [id], tags: "jp::verb"))
            #expect(!(try backend.invoke(.getNote(id: id)).tags.contains("jp::verb")))
        }
    }

    @Test func renameAndRemoveTagsCollectionWide() throws {
        try withScratchCollection("tags-collection") { backend, _ in
            let id = try addNote(backend, front: "tagged", tags: ["old::a", "keep"])
            #expect(try backend.invoke(.allTagPaths).contains("old::a"))

            try backend.invoke(.renameTags(oldPrefix: "old", newPrefix: "new"))
            let renamed = try backend.invoke(.getNote(id: id)).tags
            #expect(renamed.contains("new::a"))
            #expect(!renamed.contains("old::a"))

            try backend.invoke(.removeTags(name: "new::a"))
            #expect(!(try backend.invoke(.getNote(id: id)).tags.contains("new::a")))
            #expect(try backend.invoke(.getNote(id: id)).tags.contains("keep"))
        }
    }

    @Test func clearUnusedTags_dropsTagsWhoseLastNoteIsGone() throws {
        try withScratchCollection("tags-unused") { backend, _ in
            let id = try addNote(backend, front: "tagged", tags: ["orphan", "kept"])
            _ = try addNote(backend, front: "other", tags: ["kept"])
            #expect(try backend.invoke(.allTagPaths).sorted() == ["kept", "orphan"])

            #expect(try backend.invoke(.clearUnusedTags) == 0)

            try backend.invoke(.removeNote(id: id))
            #expect(try backend.invoke(.clearUnusedTags) == 1)
            #expect(try backend.invoke(.allTagPaths) == ["kept"])
        }
    }

    @Test func setTagCollapsed_isAccepted() throws {
        try withScratchCollection("tags-collapse") { backend, _ in
            _ = try addNote(backend, front: "tagged", tags: ["parent::child"])

            try backend.invoke(.setTagCollapsed(tag: "parent", collapsed: true))
            try backend.invoke(.setTagCollapsed(tag: "parent", collapsed: false))
        }
    }
}
