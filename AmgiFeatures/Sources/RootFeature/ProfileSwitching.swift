//
//  ProfileSwitching.swift
//  RootFeature
//
//  Created by Vladimir Gusev on 29.08.2026.
//

import AppCore
import AppShared
import AnkiBackend
import Dependencies
import Foundation
import SyncFeature
import os

/// Creates the profile's directory layout if needed and opens its collection
/// on `backend`. Shared by the bootstrap and in-app profile switching.
@MainActor
func openCollection(for profileID: String, backend: AnkiBackend) throws {
    try AppSignpost.measure("OpenCollection") {
        let ankiDir = AccountStore.profileDirectory(for: profileID)
        try FileManager.default.createDirectory(at: ankiDir, withIntermediateDirectories: true)
        let mediaPath = ankiDir.appendingPathComponent("media").path
        try FileManager.default.createDirectory(atPath: mediaPath, withIntermediateDirectories: true)
        try backend.openCollection(
            collectionPath: ankiDir.appendingPathComponent("collection.anki2").path,
            mediaFolderPath: mediaPath,
            mediaDbPath: ankiDir.appendingPathComponent("media.db").path
        )
    }
}

/// In-app profile switch: cancels any running sync, swaps the open collection
/// on the shared backend, flips the scoping anchor (sync prefs + keychain
/// identity), resets sync state, and refreshes widgets. The root view re-ids
/// on `selectedID`, so the whole UI rebuilds against the new collection.
@MainActor
func switchProfile(to account: AmgiAccount) async {
    let store = AccountStore.shared
    guard account.id != store.selectedID else { return }
    let previous = store.current

    @Dependency(\.ankiBackend) var backend
    @Dependency(\.syncCoordinator) var syncCoordinator

    await syncCoordinator.cancelAndWait()
    do {
        try backend.closeCollection()
    } catch {
        Log.decks.error("Failed to close collection during profile switch: \(error)")
    }
    store.select(account)
    do {
        try openCollection(for: account.id, backend: backend)
    } catch {
        // Roll back rather than leave the app with no open collection.
        store.select(previous)
        do {
            try openCollection(for: previous.id, backend: backend)
        } catch let rollbackError {
            // Both the switch and the rollback failed, so nothing is open.
            // Discarding this left every screen failing its fetch with no
            // explanation — the app looked empty rather than broken.
            Log.decks.error("Profile switch and rollback both failed: \(rollbackError)")
            store.switchFailure = """
                Couldn't open either profile's collection. Quit and reopen \
                Amgi. If that doesn't help, reset the collection from \
                Settings > Maintenance.
                """
        }
        return
    }
    syncCoordinator.resetForProfileSwitch()
    await writeWidgetSnapshot()
}
