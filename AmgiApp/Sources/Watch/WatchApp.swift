import AnkiBackend
import AnkiSync
import Dependencies
import Foundation
import Sharing
import SwiftUI
import AmgiTheme

@main
struct WatchApp: App {
    @State private var isLoggedIn = KeychainHelper.loadHostKey() != nil
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
            try? backend.checkDatabase()
            $0.ankiBackend = backend
        }
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if isLoggedIn {
                    WatchContentView()
                } else {
                    WatchLoginView {
                        isLoggedIn = true
                    }
                }
            }
            .themedRoot()
        }
    }
}
