//
//  WatchApp.swift
//  AmgiWatchApp
//
//  Created by Leaf Eriksen on 17.07.2026.
//

import AnkiBackend
import AnkiSync
import Dependencies
import Foundation
import Sharing
import SwiftUI
import Theme
import WatchFeature

@main
struct WatchApp: App {
    @State private var isLoggedIn = KeychainHelper.loadHostKey() != nil
    private let startupError: (any Error)?

    // Bootstrap belongs in init, not .onAppear. From .onAppear it ran *after*
    // the content views were constructed — and their `.task` may already have
    // resolved @Dependency(\.ankiBackend), which swift-dependencies then
    // caches, silently binding the unimplemented test client. .onAppear also
    // fires again on reappearance, constructing a second AnkiBackend over the
    // same SQLite file. The iOS scheme doesn't build this target, so nothing
    // caught it.
    init() {
        var failure: (any Error)?
        do {
            try Self.setUpBackend()
        } catch {
            failure = error
        }
        startupError = failure
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = startupError {
                    VStack(spacing: 20) {
                        Text("Startup Error")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .multilineTextAlignment(.center)
                        Button("Sign Out") {
                            isLoggedIn = false
                        }
                    }
                    .padding()
                    .themedRoot()
                } else if isLoggedIn {
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

    private static func setUpBackend() throws {
        try prepareDependencies {
            let backend = try AnkiBackend(preferredLangs: ["en"])
            // Unprofiled path on purpose: the watch is a separate device
            // container with no profile registry, so it always resolves to
            // the "default" scope (see AnkiKit.ProfileScope). It is not the
            // phone's legacy pre-migration directory.
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first ?? URL.applicationSupportDirectory
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
            $0.ankiBackend = backend
        }
    }
}
