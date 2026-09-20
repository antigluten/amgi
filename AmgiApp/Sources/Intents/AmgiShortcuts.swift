//
//  AmgiShortcuts.swift
//  AmgiApp
//
//  Created by Vladimir Gusev on 19.09.2026.
//

import AppIntents
import IntentsFeature

struct AmgiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StudyDeckIntent(),
            phrases: [
                "Study in \(.applicationName)",
                "Review cards in \(.applicationName)",
                "Start a review in \(.applicationName)",
            ],
            shortTitle: "Study Deck",
            systemImageName: "graduationcap"
        )
        AppShortcut(
            intent: SyncCollectionIntent(),
            phrases: [
                "Sync \(.applicationName)",
                "Sync my \(.applicationName) collection",
            ],
            shortTitle: "Sync Collection",
            systemImageName: "arrow.triangle.2.circlepath"
        )
        AppShortcut(
            intent: DueCountIntent(),
            phrases: [
                "What's due in \(.applicationName)",
                "How many cards are due in \(.applicationName)",
            ],
            shortTitle: "Cards Due",
            systemImageName: "tray.full"
        )
    }
}
