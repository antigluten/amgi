//
//  ScratchCollection.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
@testable import AnkiBackend

func withScratchCollection<T>(
    _ label: String,
    _ body: (AnkiBackend, URL) throws -> T
) throws -> T {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(label)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let backend = try AnkiBackend()
    try backend.openCollection(
        collectionPath: dir.appendingPathComponent("collection.anki2").path,
        mediaFolderPath: dir.appendingPathComponent("media").path,
        mediaDbPath: dir.appendingPathComponent("media.db").path
    )
    defer { try? backend.closeCollection() }

    return try body(backend, dir)
}
