//
//  ImportExportLiveTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

@Suite struct ImportExportLiveTests {
    private static let separator = "\u{1f}"

    @discardableResult
    private func addBasicNote(
        _ backend: AnkiBackend, front: String, back: String, deckId: DeckID = DeckID(1)
    ) throws -> NoteID {
        let names = try backend.invoke(.notetypeNames)
        let basic = try #require(names.first { $0.name == "Basic" })
        var template = try backend.invoke(.newNote(notetypeId: basic.id))
        template.fields[0] = front
        template.fields[1] = back
        try backend.invoke(.addNote(template: template, deckId: deckId))
        return try #require(try backend.invoke(.searchNoteIds(query: "\"\(front)\"")).first)
    }

    private func expectPackageArchive(at path: String, _ label: Comment) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        #expect(data.count > 0, label)
        #expect(data.prefix(2) == Data("PK".utf8), label)
        #expect(
            data.range(of: Data("collection.anki2".utf8)) != nil,
            label
        )
    }

    @Test func exportAnkiPackage_limitsToOneDeck_andImportAnkiPackageTakesItBack() throws {
        try withScratchCollection("apkg-export") { source, dir in
            let template = try source.invoke(.newDeck)
            let probe = try source.invoke(.addDeck(template: template, name: "Probe"))
            try addBasicNote(source, front: "alpha", back: "one", deckId: probe.id)
            try addBasicNote(source, front: "beta", back: "two", deckId: probe.id)
            try addBasicNote(source, front: "gamma", back: "three")

            let path = dir.appendingPathComponent("probe.apkg").path
            let exported = try source.invoke(
                .exportAnkiPackage(
                    deckId: probe.id,
                    outPath: path,
                    withScheduling: true,
                    withDeckConfigs: true,
                    withMedia: false,
                    legacy: false
                )
            )
            #expect(exported == 2, "the deck holds two notes; gamma is in Default")
            try expectPackageArchive(at: path, "exported .apkg")

            try withScratchCollection("apkg-import") { target, _ in
                #expect(try target.invoke(.searchNoteIds(query: "deck:*")).isEmpty)

                let log = try target.invoke(.importAnkiPackage(path: path))
                #expect(log.newCount == 2)
                #expect(log.updatedCount == 0)
                #expect(log.duplicateCount == 0)

                #expect(try target.invoke(.searchNoteIds(query: "alpha")).count == 1)
                #expect(try target.invoke(.searchNoteIds(query: "beta")).count == 1)
                #expect(
                    try target.invoke(.searchNoteIds(query: "gamma")).isEmpty,
                    "gamma was outside the exported deck"
                )
                #expect(try target.invoke(.deckNames).contains { $0.name == "Probe" })
            }
        }
    }

    @Test func exportAnkiPackageForMerge_thenImportForMerge_updatesTheEditedNote() throws {
        try withScratchCollection("merge-export") { source, dir in
            let noteID = try addBasicNote(source, front: "alpha", back: "one")
            try addBasicNote(source, front: "beta", back: "two")

            let first = dir.appendingPathComponent("first.apkg").path
            try source.invoke(.exportAnkiPackageForMerge(outPath: first))
            try expectPackageArchive(at: first, "merge export")

            try withScratchCollection("merge-import") { target, _ in
                #expect(try target.invoke(.importAnkiPackage(path: first)).newCount == 2)

                Thread.sleep(forTimeInterval: 1.1)

                var edited = try source.invoke(.getNote(id: noteID))
                edited.flds = "alpha\(Self.separator)one edited"
                try source.invoke(.updateNote(edited))
                #expect(
                    try source.invoke(.getNote(id: noteID)).flds == "alpha\(Self.separator)one edited",
                    "precondition: the source note really changed"
                )

                let second = dir.appendingPathComponent("second.apkg").path
                try source.invoke(.exportAnkiPackageForMerge(outPath: second))

                let log = try target.invoke(.importAnkiPackageForMerge(path: second))
                #expect(log.newCount == 0, "both notes already exist here")
                #expect(log.updatedCount == 1)

                let merged = try target.invoke(
                    .getNote(id: try #require(try target.invoke(.searchNoteIds(query: "alpha")).first))
                )
                #expect(merged.flds == "alpha\(Self.separator)one edited")
                #expect(try target.invoke(.searchNoteIds(query: "deck:*")).count == 2)
            }
        }
    }

    @Test func exportCollectionPackage_writesAColpkg_andClosesTheCollection() throws {
        let bareSize = try withScratchCollection("colpkg-bare") { backend, dir in
            try addBasicNote(backend, front: "alpha", back: "one")

            let bare = dir.appendingPathComponent("bare.colpkg").path
            try backend.invoke(.exportCollectionPackage(outPath: bare, includeMedia: false))
            try expectPackageArchive(at: bare, "colpkg without media")

            #expect(throws: (any Error).self, "the export closed the collection") {
                try backend.invoke(.searchNoteIds(query: "alpha"))
            }

            try backend.reopenCollection()
            #expect(try backend.invoke(.searchNoteIds(query: "alpha")).count == 1)

            return try Data(contentsOf: URL(fileURLWithPath: bare)).count
        }

        try withScratchCollection("colpkg-media") { backend, dir in
            try addBasicNote(backend, front: "alpha", back: "one")

            let media = dir.appendingPathComponent("media")
            try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
            try Data((0..<65_536).map { _ in UInt8.random(in: 0...255) })
                .write(to: media.appendingPathComponent("packed.bin"))

            let withMedia = dir.appendingPathComponent("with-media.colpkg").path
            try backend.invoke(.exportCollectionPackage(outPath: withMedia, includeMedia: true))
            try expectPackageArchive(at: withMedia, "colpkg with media")

            let mediaSize = try Data(contentsOf: URL(fileURLWithPath: withMedia)).count
            #expect(
                mediaSize > bareSize + 32_768,
                "includeMedia: true must bundle the 64 KB media file (bare was \(bareSize), this \(mediaSize))"
            )
        }
    }
}
