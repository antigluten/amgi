//
//  WidgetTimelineProvider.swift
//  WidgetFeature
//
//  Created by Vladimir Gusev on 07.04.2026.
//

import WidgetKit
import Foundation
import AppCore

struct WidgetEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
}

struct WidgetTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = AmgiWidgetIntent
    typealias Entry = WidgetEntry

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func snapshot(for configuration: AmgiWidgetIntent, in context: Context) async -> WidgetEntry {
        if context.isPreview {
            return WidgetEntry(date: Date(), snapshot: .placeholder)
        }
        return WidgetEntry(date: Date(), snapshot: read(configuration) ?? .placeholder)
    }

    func timeline(for configuration: AmgiWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let now = Date()
        guard let snapshot = read(configuration) else {
            // No snapshot at all — the app has never written one, so nothing
            // to poll for. Retry occasionally in case it launches.
            return Timeline(
                entries: [WidgetEntry(date: now, snapshot: .placeholder)],
                policy: .after(now.addingTimeInterval(3600))
            )
        }

        // The snapshot carries a per-Anki-day forecast; replay it as one
        // entry per rollover boundary. No background execution needed, and a
        // stale file still yields a correct entry for the current Anki-day.
        let entries = snapshot.projectedEntries(now: now).map {
            WidgetEntry(date: $0.date, snapshot: $0.snapshot)
        }
        // With a single entry (no forecast / forecast exhausted) .atEnd would
        // re-invoke immediately in a loop — back off instead.
        let policy: TimelineReloadPolicy =
            entries.count > 1 ? .atEnd : .after(now.addingTimeInterval(3600))
        return Timeline(entries: entries, policy: policy)
    }
}

private extension WidgetTimelineProvider {
    /// Configured deck's snapshot; falls back to the All Decks aggregate when
    /// that deck no longer exists (deleted, or a profile switch).
    func read(_ configuration: AmgiWidgetIntent) -> WidgetSnapshot? {
        let deckId = Int64(configuration.deck?.id ?? "0") ?? 0
        return WidgetSnapshotStore.read(deckId: deckId) ?? WidgetSnapshotStore.read(deckId: 0)
    }
}
