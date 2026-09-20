//
//  SyncCollectionIntent.swift
//  IntentsFeature
//
//  Created by Vladimir Gusev on 19.09.2026.
//

import AnkiClients
import AnkiKit
import AppCore
import AppShared
public import AppIntents
import Dependencies
import Foundation

/// "Sync Amgi" — a headless collection sync.
public struct SyncCollectionIntent: AppIntent {
    public init() {}

    public static let title: LocalizedStringResource = "Sync Collection"
    public static let description = IntentDescription(
        "Syncs your collection with the sync server.",
        categoryName: "Collection"
    )
    public static let openAppWhenRun = false

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary: SyncSummary
        do {
            summary = try await SyncIntentRunner.run()
        } catch {
            throw AmgiIntentError.syncFailed(error.localizedDescription)
        }
        let pushed = summary.cardsPushed + summary.notesPushed
        let pulled = summary.cardsPulled + summary.notesPulled
        let dialog: IntentDialog = pushed == 0 && pulled == 0
            ? "Already up to date."
            : "Synced — ^[\(pushed) change](inflect: true) up, ^[\(pulled) change](inflect: true) down."
        return .result(dialog: dialog)
    }
}

enum SyncIntentRunner {
    static func run() async throws -> SyncSummary {
        @Dependency(\.syncClient) var syncClient
        let summary = try await syncClient.sync()
        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: SyncPreferences.Keys.lastCollectionSyncedAtForCurrentUser()
        )
        UserDefaults.standard.set(
            false,
            forKey: SyncPreferences.Keys.needsFullSyncForCurrentUser()
        )
        await writeWidgetSnapshot()
        return summary
    }
}
