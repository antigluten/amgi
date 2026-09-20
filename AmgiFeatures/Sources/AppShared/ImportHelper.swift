//
//  ImportHelper.swift
//  AppShared
//
//  Created by Vladimir Gusev on 30.03.2026.
//

import AnkiBackend
public import AnkiKit
import AnkiServices
import Dependencies
public import Foundation

enum ImportError: Error, LocalizedError {
    case accessDenied
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Cannot access the selected file"
        case .importFailed(let msg): return msg
        }
    }
}

public enum ImportHelper {
    public static func importPackage(from url: URL) async throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tempFile)
        try FileManager.default.copyItem(at: url, to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        @Dependency(\.importExportService) var importExportService
        let path = tempFile.path
        return try await backendOffload { try importExportService.importAnkiPackage(path) }
    }

    /// Exports a single deck as an `.apkg` file in the temporary directory and
    /// returns the URL. The default options preserve scheduling, deck configs,
    /// and media — matching upstream Anki's "Export including media" preset.
    public static func exportDeck(
        deckId: DeckID,
        deckName: String,
        withScheduling: Bool = true,
        withDeckConfigs: Bool = true,
        withMedia: Bool = true
    ) throws -> URL {
        let safeName = deckName
            .replacingOccurrences(of: "::", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let filename = "\(safeName).apkg"
        let tempDir = FileManager.default.temporaryDirectory
        let outPath = tempDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: outPath)

        @Dependency(\.importExportService) var importExportService
        _ = try importExportService.exportDeckPackage(
            deckId,
            outPath.path,
            withScheduling,
            withDeckConfigs,
            withMedia,
            false  // legacy
        )

        return outPath
    }
}
