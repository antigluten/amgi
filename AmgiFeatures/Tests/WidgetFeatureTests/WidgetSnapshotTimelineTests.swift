import Foundation
import Testing
import WidgetKit
@testable import AppCore
@testable import WidgetFeature

struct WidgetSnapshotTimelineTests {
    private struct Fixture {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let now: Date
        let provider: WidgetTimelineProvider
        let intent: AmgiWidgetIntent

        static func file(_ id: Int64, in directory: URL) -> URL {
            directory.appendingPathComponent("widget-snapshot-\(id).json")
        }

        func file(_ id: Int64) -> URL { Self.file(id, in: directory) }

        init(deckIDs: [Int64], deck: DeckEntity? = DeckEntity(id: "42", name: "Japanese")) throws {
            let dir = directory
            let read: @Sendable (Int64) -> WidgetSnapshot? = {
                WidgetSnapshotStore.read(from: Self.file($0, in: dir))
            }
            let now = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 12)))
            self.now = now
            provider = WidgetTimelineProvider(snapshotForDeck: read)
            let intent = AmgiWidgetIntent()
            intent.deck = deck
            self.intent = intent
            let forecast = WidgetSnapshot.Forecast(rolloverHour: 4, dayZero: AnkiDay.start(of: now, rolloverHour: 4), days: [
                .init(newCount: 4, learnCount: 2, reviewCount: 3),
                .init(newCount: 4, learnCount: 0, reviewCount: 11),
            ])
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            do {
                for id in deckIDs {
                    try WidgetSnapshotStore.write(WidgetSnapshot(
                        deckId: id, deckName: id == 0 ? "All Decks" : "Japanese",
                        newCount: 4, learnCount: 2, reviewCount: 3, reviewedToday: 7,
                        streak: 5, lastSevenDays: [1, 2, 3, 4, 5, 6, 7],
                        snapshotDate: now, forecast: forecast
                    ), to: Self.file(id, in: dir))
                }
            } catch {
                try? FileManager.default.removeItem(at: dir)
                throw error
            }
        }

        func cleanup() { try? FileManager.default.removeItem(at: directory) }
    }

    private func expectForecast(_ timeline: Timeline<WidgetEntry>, deckId: Int64) {
        #expect(timeline.entries.map(\.snapshot.deckId) == [deckId, deckId])
        #expect(timeline.entries.map(\.snapshot.reviewCount) == [3, 11])
        #expect(timeline.entries.map(\.snapshot.reviewedToday) == [7, 0])
        #expect(timeline.policy == .atEnd)
    }

    @Test
    func presentDeckRendersItsOwnForecast() throws {
        let fixture = try Fixture(deckIDs: [0, 42])
        defer { fixture.cleanup() }
        expectForecast(fixture.provider.timeline(for: fixture.intent, now: fixture.now), deckId: 42)
    }

    @Test
    func deletedDeckWithStaleEntityFallsBackToAllDecks() throws {
        let fixture = try Fixture(deckIDs: [0, 42])
        defer { fixture.cleanup() }
        try FileManager.default.removeItem(at: fixture.file(42))
        expectForecast(fixture.provider.timeline(for: fixture.intent, now: fixture.now), deckId: 0)
    }

    @Test
    func nilDeckRendersAllDecks() throws {
        let fixture = try Fixture(deckIDs: [0], deck: nil)
        defer { fixture.cleanup() }
        expectForecast(fixture.provider.timeline(for: fixture.intent, now: fixture.now), deckId: 0)
    }

    @Test
    func noSnapshotsYieldsPlaceholderAndBacksOffAnHour() throws {
        let fixture = try Fixture(deckIDs: [])
        defer { fixture.cleanup() }
        let timeline = fixture.provider.timeline(for: fixture.intent, now: fixture.now)
        #expect(timeline.entries.count == 1)
        #expect(timeline.entries.first?.snapshot.reviewCount == WidgetSnapshot.placeholder.reviewCount)
        #expect(timeline.policy == .after(fixture.now.addingTimeInterval(3600)))
    }
}
