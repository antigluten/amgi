import AnkiServices
import Dependencies
import Foundation

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

enum ImportHelper {
    static func importPackage(from url: URL) throws -> String {
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
        return try importExportService.importAnkiPackage(tempFile.path)
    }

    static func exportCollection(to filename: String = "collection.colpkg") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let outPath = tempDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: outPath)

        @Dependency(\.importExportService) var importExportService
        try importExportService.exportCollectionPackage(outPath.path, true)

        return outPath
    }
}
