//
//  WidgetSnapshotProjectionTests.swift
//  AppCoreTests
//
//  Created by Vladimir Gusev on 28.07.2026.
//

import Foundation
import Testing
@testable import AppCore

@Suite struct WidgetSnapshotProjectionTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ day: Int, _ hour: Int, minute: Int = 0) -> Date {
        DateComponents(
            calendar: calendar, year: 2026, month: 7, day: day, hour: hour, minute: minute
        ).date!
    }

    private func snapshot(
        reviewedToday: Int = 10,
        streak: Int = 5,
        forecast: WidgetSnapshot.Forecast?
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            deckId: 1,
            deckName: "Korean",
            newCount: 3,
            learnCount: 2,
            reviewCount: 20,
            reviewedToday: reviewedToday,
            streak: streak,
            lastSevenDays: [1, 2, 3, 4, 5, 6, 7],
            snapshotDate: date(10, 12),
            forecast: forecast
        )
    }

    private func forecast(days: [WidgetSnapshot.DayCounts]) -> WidgetSnapshot.Forecast {
        .init(rolloverHour: 4, dayZero: date(10, 4), days: days)
    }

    private let futureDays: [WidgetSnapshot.DayCounts] = [
        .init(newCount: 3, learnCount: 2, reviewCount: 20),
        .init(newCount: 3, learnCount: 0, reviewCount: 30),
        .init(newCount: 3, learnCount: 0, reviewCount: 42),
    ]

    // MARK: AnkiDay

    @Test func dayStartsAtRolloverHourAfterRollover() {
        #expect(AnkiDay.start(of: date(10, 12), rolloverHour: 4, calendar: calendar) == date(10, 4))
    }

    @Test func beforeRolloverBelongsToPreviousDay() {
        #expect(AnkiDay.start(of: date(10, 1), rolloverHour: 4, calendar: calendar) == date(9, 4))
    }

    @Test func exactRolloverInstantStartsTheNewDay() {
        #expect(AnkiDay.start(of: date(10, 4), rolloverHour: 4, calendar: calendar) == date(10, 4))
    }

    // MARK: Fresh snapshot

    @Test func freshSnapshotEmitsOneEntryPerForecastDayAtRolloverBoundaries() {
        let snap = snapshot(forecast: forecast(days: futureDays))
        let entries = snap.projectedEntries(now: date(10, 12), calendar: calendar)
        #expect(entries.count == 3)
        #expect(entries[0].date == date(10, 12))
        #expect(entries[0].snapshot.reviewCount == 20)
        #expect(entries[0].snapshot.reviewedToday == 10)
        #expect(entries[1].date == date(11, 4))
        #expect(entries[1].snapshot.reviewCount == 30)
        #expect(entries[1].snapshot.reviewedToday == 0)
        #expect(entries[2].date == date(12, 4))
        #expect(entries[2].snapshot.reviewCount == 42)
    }

    @Test func streakSurvivesFirstBoundaryOnlyWhenWriteDayHadReviews() {
        let snap = snapshot(reviewedToday: 10, streak: 5, forecast: forecast(days: futureDays))
        let entries = snap.projectedEntries(now: date(10, 12), calendar: calendar)
        #expect(entries[1].snapshot.streak == 5)
        #expect(entries[2].snapshot.streak == 0)
    }

    @Test func streakBreaksAtFirstBoundaryWhenWriteDayHadNoReviews() {
        let snap = snapshot(reviewedToday: 0, streak: 5, forecast: forecast(days: futureDays))
        let entries = snap.projectedEntries(now: date(10, 12), calendar: calendar)
        #expect(entries[1].snapshot.streak == 0)
    }

    @Test func chartShiftsAndZeroPadsPerDay() {
        let snap = snapshot(forecast: forecast(days: futureDays))
        let entries = snap.projectedEntries(now: date(10, 12), calendar: calendar)
        #expect(entries[1].snapshot.lastSevenDays == [2, 3, 4, 5, 6, 7, 0])
        #expect(entries[2].snapshot.lastSevenDays == [3, 4, 5, 6, 7, 0, 0])
    }

    @Test func chartAnchorAdvancesWithTheShiftedWindow() {
        let snap = snapshot(forecast: forecast(days: futureDays))
        let entries = snap.projectedEntries(now: date(10, 12), calendar: calendar)
        #expect(entries[0].snapshot.snapshotDate == date(10, 12))
        #expect(entries[1].snapshot.snapshotDate == date(11, 12))
        #expect(entries[2].snapshot.snapshotDate == date(12, 12))
    }

    // MARK: Stale snapshot (provider re-invoked days later, app never opened)

    @Test func staleSnapshotProjectsFirstEntryToCurrentAnkiDay() {
        let snap = snapshot(forecast: forecast(days: futureDays))
        let entries = snap.projectedEntries(now: date(12, 12), calendar: calendar)
        #expect(entries.count == 1)
        #expect(entries[0].snapshot.reviewCount == 42)
        #expect(entries[0].snapshot.reviewedToday == 0)
        #expect(entries[0].snapshot.streak == 0)
    }

    @Test func nowBeforeRolloverStillCountsAsWriteDay() {
        // 01:00 the next calendar day is still Anki-day 0 (rollover 4 am).
        let snap = snapshot(forecast: forecast(days: futureDays))
        let entries = snap.projectedEntries(now: date(11, 1), calendar: calendar)
        #expect(entries[0].snapshot.reviewCount == 20)
        #expect(entries[0].snapshot.reviewedToday == 10)
        #expect(entries.count == 3)
    }

    @Test func exhaustedForecastClampsToLastDay() {
        let snap = snapshot(forecast: forecast(days: futureDays))
        let entries = snap.projectedEntries(now: date(20, 12), calendar: calendar)
        #expect(entries.count == 1)
        #expect(entries[0].snapshot.reviewCount == 42)
        #expect(entries[0].snapshot.streak == 0)
    }

    @Test func missingForecastFallsBackToSingleLiveEntry() {
        let snap = snapshot(forecast: nil)
        let entries = snap.projectedEntries(now: date(10, 12), calendar: calendar)
        #expect(entries.count == 1)
        #expect(entries[0].snapshot.reviewCount == 20)
    }

    @Test func preForecastSnapshotFileStillDecodes() throws {
        let json = """
        {"deckId":1,"deckName":"Korean","newCount":3,"learnCount":2,"reviewCount":20,\
        "reviewedToday":10,"streak":5,"lastSevenDays":[1,2,3,4,5,6,7],\
        "snapshotDate":"2026-07-10T12:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snap = try decoder.decode(WidgetSnapshot.self, from: Data(json.utf8))
        #expect(snap.forecast == nil)
        #expect(snap.reviewCount == 20)
    }
}
