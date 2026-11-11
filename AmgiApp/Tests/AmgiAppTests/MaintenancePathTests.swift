import AnkiBackend
import AnkiServices
import Dependencies
import Foundation
import Testing
@testable import SettingsFeature

@MainActor
@Suite(.serialized)
struct MaintenancePathTests {
    @Test func databaseCheckUsesNativeBackendAndReportsItsError() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("maintenance-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let backend = try AnkiBackend()
        try backend.openCollection(
            collectionPath: directory.appendingPathComponent("collection.anki2").path,
            mediaFolderPath: directory.appendingPathComponent("media").path,
            mediaDbPath: directory.appendingPathComponent("media.db").path
        )
        defer { try? backend.closeCollection() }
        try await withDependencies {
            $0.ankiBackend = backend
            $0.collectionService = .liveValue
        } operation: {
            let model = MaintenanceModel()
            await model.checkDatabase()
            #expect(model.statusMessage == "Database check passed")
            #expect(!model.isChecking)
            try backend.closeCollection()
            var nativeError: String?
            do {
                _ = try CollectionService.liveValue.checkDatabase()
                Issue.record("Closed native collection must fail")
            } catch {
                nativeError = error.localizedDescription
            }
            let expected = try #require(nativeError)
            await model.checkDatabase()
            #expect(model.statusMessage == "Database check error: \(expected)")
            #expect(!model.isChecking)
        }
    }
}
