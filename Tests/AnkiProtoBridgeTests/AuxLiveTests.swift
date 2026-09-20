//
//  AuxLiveTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

@Suite struct AuxLiveTests {
    private static let separator = "\u{1f}"

    @discardableResult
    private func addNote(
        _ backend: AnkiBackend, notetype: String = "Basic", front: String, back: String = "back"
    ) throws -> NoteID {
        let names = try backend.invoke(.notetypeNames)
        let type = try #require(names.first { $0.name == notetype })
        var template = try backend.invoke(.newNote(notetypeId: type.id))
        template.fields[0] = front
        template.fields[1] = back
        try backend.invoke(.addNote(template: template, deckId: DeckID(1)))
        let ids = try backend.invoke(.searchNoteIds(query: "deck:Default"))
        return try #require(ids.max { $0.rawValue < $1.rawValue })
    }

    @Test func findDuplicates_isEmptyWhenEveryFirstFieldIsUnique() throws {
        try withScratchCollection("aux-none") { backend, _ in
            #expect(try backend.invoke(.findDuplicates).isEmpty)

            try addNote(backend, front: "alpha")
            try addNote(backend, front: "beta")
            #expect(try backend.invoke(.findDuplicates).isEmpty)
        }
    }

    @Test func findDuplicates_groupsNotesSharingAFirstField() throws {
        try withScratchCollection("aux-groups") { backend, _ in
            let first = try addNote(backend, front: "同じ", back: "one")
            let second = try addNote(backend, front: "同じ", back: "two")
            try addNote(backend, front: "different")

            let groups = try backend.invoke(.findDuplicates)
            #expect(groups.count == 1)

            let group = try #require(groups.first)
            #expect(group.value == "同じ")
            #expect(group.noteIDs.sorted { $0.rawValue < $1.rawValue } == [first, second])
        }
    }

    @Test func findDuplicates_ignoresMarkupTheWayUpstreamDoes() throws {
        try withScratchCollection("aux-html") { backend, _ in
            let plain = try addNote(backend, front: "duplicate", back: "one")
            let marked = try addNote(backend, front: "<b>duplicate</b>", back: "two")

            let groups = try backend.invoke(.findDuplicates)
            #expect(groups.count == 1)
            #expect(groups.first?.value == "duplicate")
            #expect(groups.first?.noteIDs.sorted { $0.rawValue < $1.rawValue } == [plain, marked])
        }
    }

    @Test func findDuplicates_doesNotGroupAcrossNotetypes() throws {
        try withScratchCollection("aux-notetypes") { backend, _ in
            try addNote(backend, notetype: "Basic", front: "shared")
            try addNote(backend, notetype: "Basic (and reversed card)", front: "shared")

            #expect(try backend.invoke(.findDuplicates).isEmpty)
        }
    }

    @Test func findDuplicates_skipsBlankFirstFields() throws {
        try withScratchCollection("aux-blank") { backend, _ in
            let id = try addNote(backend, front: "placeholder", back: "one")
            var note = try backend.invoke(.getNote(id: id))
            note.flds = "\(Self.separator)one"
            try backend.invoke(.updateNote(note))

            let other = try addNote(backend, front: "placeholder2", back: "two")
            var second = try backend.invoke(.getNote(id: other))
            second.flds = "\(Self.separator)two"
            try backend.invoke(.updateNote(second))

            #expect(try backend.invoke(.findDuplicates).isEmpty)
        }
    }

    @Test func auxService_reportsAnUnknownMethodAsAnError() throws {
        try withScratchCollection("aux-unknown") { backend, _ in
            let unknown = Request<Data>(
                serviceId: ServiceID.aux,
                methodId: 99,
                encode: { Data() },
                decode: { $0 }
            )

            #expect {
                try backend.invoke(unknown)
            } throws: { error in
                guard let error = error as? BackendError else { return false }
                return error.kind == .invalidInput
                    && error.message.contains("unknown aux method 99")
            }
        }
    }
}
