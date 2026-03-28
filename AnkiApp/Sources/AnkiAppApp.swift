import SwiftUI
import AnkiBackend
import Dependencies
import Foundation

@main
struct AnkiAppApp: App {
    init() {
        try! prepareDependencies {
            let backend = try AnkiBackend(preferredLangs: ["en"])

            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!
            let ankiDir = appSupport.appendingPathComponent("AnkiCollection", isDirectory: true)
            try FileManager.default.createDirectory(at: ankiDir, withIntermediateDirectories: true)

            let collectionPath = ankiDir.appendingPathComponent("collection.anki2").path
            let mediaPath = ankiDir.appendingPathComponent("media").path
            let mediaDbPath = ankiDir.appendingPathComponent("media.db").path
            try FileManager.default.createDirectory(
                atPath: mediaPath, withIntermediateDirectories: true
            )

            try backend.openCollection(
                collectionPath: collectionPath,
                mediaFolderPath: mediaPath,
                mediaDbPath: mediaDbPath
            )

            // Run CheckDatabase to repair any inconsistencies after sync/migration
            // CollectionService = service 2, CheckDatabase = method 0
            _ = try? backend.call(service: 2, method: 0)

            $0.ankiBackend = backend
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
