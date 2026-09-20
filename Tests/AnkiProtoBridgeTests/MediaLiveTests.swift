//
//  MediaLiveTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

@Suite struct MediaLiveTests {
    private func writeUnusedMedia(_ name: String, in dir: URL) throws {
        let media = dir.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        try Data("not really a png".utf8)
            .write(to: media.appendingPathComponent(name))
    }

    @Test func checkMedia_seesAFileNoNoteReferences() throws {
        try withScratchCollection("media-check") { backend, dir in
            #expect(try backend.invoke(.checkMedia).unused.isEmpty)

            try writeUnusedMedia("orphan.png", in: dir)

            let result = try backend.invoke(.checkMedia)
            #expect(result.unused == ["orphan.png"])
            #expect(result.missing.isEmpty)
            #expect(!result.report.isEmpty)
        }
    }

    @Test func trashMediaFiles_thenRestoreThenEmpty() throws {
        try withScratchCollection("media-trash") { backend, dir in
            try writeUnusedMedia("orphan.png", in: dir)
            #expect(try backend.invoke(.checkMedia).unused == ["orphan.png"])

            try backend.invoke(.trashMediaFiles(filenames: ["orphan.png"]))
            #expect(try backend.invoke(.checkMedia).unused.isEmpty)
            #expect(try backend.invoke(.checkMedia).haveTrash)

            try backend.invoke(.restoreMediaTrash)
            #expect(try backend.invoke(.checkMedia).unused == ["orphan.png"])

            try backend.invoke(.trashMediaFiles(filenames: ["orphan.png"]))
            try backend.invoke(.emptyMediaTrash)
            #expect(try backend.invoke(.checkMedia).unused.isEmpty)
            #expect(!(try backend.invoke(.checkMedia).haveTrash))
        }
    }

    @Test func mediaSyncStatus_isIdleAndAbortIsSafeWhenNothingIsRunning() throws {
        try withScratchCollection("media-sync-status") { backend, _ in
            #expect(try backend.invoke(.mediaSyncStatus).active == false)

            try backend.invoke(.abortMediaSync)
            #expect(try backend.invoke(.mediaSyncStatus).active == false)
        }
    }
}
