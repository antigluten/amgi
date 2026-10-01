import Foundation
import Testing
import WidgetKit
@testable import AppCore
@testable import WidgetFeature

struct WidgetSnapshotTimelineTests {
    @Test
    func actualSnapshotFilesSurviveDeckDeletionAndReachTimeline() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file: @Sendable (Int64) -> URL = { directory.appendingPathComponent("widget-snapshot-\($0).json") }
        let read: @Sendable (Int64) -> WidgetSnapshot? = { WidgetSnapshotStore.read(from: file($0)) }
        let query = DeckEntityQuery(snapshots: { [0, 42].compactMap(read) })
        let provider = WidgetTimelineProvider(snapshotForDeck: read)
        let now = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 12)))
        let dayZero = AnkiDay.start(of: now, rolloverHour: 4)
        let forecast = WidgetSnapshot.Forecast(rolloverHour: 4, dayZero: dayZero, days: [
            .init(newCount: 4, learnCount: 2, reviewCount: 3),
            .init(newCount: 4, learnCount: 0, reviewCount: 11),
        ])
        for id in [Int64(0), 42] {
            try WidgetSnapshotStore.write(WidgetSnapshot(
                deckId: id, deckName: id == 0 ? "All Decks" : "Japanese",
                newCount: 4, learnCount: 2, reviewCount: 3, reviewedToday: 7,
                streak: 5, lastSevenDays: [1, 2, 3, 4, 5, 6, 7],
                snapshotDate: now, forecast: forecast
            ), to: file(id))
        }
        var intent = AmgiWidgetIntent()
        for expectedID in [Int64(42), 0] {
            intent.deck = try #require(try await query.entities(for: ["42"]).first)
            let timeline = provider.timeline(for: intent, now: now)
            #expect(timeline.entries.map(\.snapshot.deckId) == [expectedID, expectedID])
            #expect(timeline.entries.map(\.snapshot.reviewCount) == [3, 11])
            #expect(timeline.entries.map(\.snapshot.reviewedToday) == [7, 0])
            #expect(timeline.policy == .atEnd)
            if expectedID == 42 { try FileManager.default.removeItem(at: file(42)) }
        }
        try FileManager.default.removeItem(at: file(0))
        let defaultDeck = try #require(await query.defaultResult())
        #expect(try await query.entities(for: [defaultDeck.id]).first?.id == "0")
        #expect(try await query.entities(for: ["not-a-deck"]).isEmpty)
        let emptyTimeline = provider.timeline(for: intent, now: now)
        #expect(emptyTimeline.entries.count == 1)
        #expect(emptyTimeline.policy == .after(now.addingTimeInterval(3600)))
    }
}
