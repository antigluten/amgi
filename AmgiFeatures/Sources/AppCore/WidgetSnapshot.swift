//
//  WidgetSnapshot.swift
//  AppCore
//
//  Created by Vladimir Gusev on 07.04.2026.
//

public import Foundation

public struct WidgetSnapshot: Codable, Sendable {
    public var deckId: Int64
    public var deckName: String
    public var newCount: Int
    public var learnCount: Int
    public var reviewCount: Int
    public var reviewedToday: Int
    public var streak: Int
    public var lastSevenDays: [Int]   // index 0 = 6 days ago, index 6 = today
    public var snapshotDate: Date
    /// Optional so pre-forecast snapshot files still decode after an update.
    public var forecast: Forecast? = nil

    public init(
        deckId: Int64,
        deckName: String,
        newCount: Int,
        learnCount: Int,
        reviewCount: Int,
        reviewedToday: Int,
        streak: Int,
        lastSevenDays: [Int],
        snapshotDate: Date,
        forecast: Forecast? = nil
    ) {
        self.deckId = deckId
        self.deckName = deckName
        self.newCount = newCount
        self.learnCount = learnCount
        self.reviewCount = reviewCount
        self.reviewedToday = reviewedToday
        self.streak = streak
        self.lastSevenDays = lastSevenDays
        self.snapshotDate = snapshotDate
        self.forecast = forecast
    }

    public var totalDue: Int { newCount + learnCount + reviewCount }

    /// Precomputed per-Anki-day due counts. While the app is closed the
    /// collection cannot change, so the future is fully known at write time;
    /// the widget replays it with zero background execution.
    public struct Forecast: Codable, Sendable, Equatable {
        /// Anki's day-boundary hour (default 4 am) — not calendar midnight.
        public var rolloverHour: Int
        /// Start of the Anki day the snapshot was written in.
        public var dayZero: Date
        /// Index 0 = the write day (mirrors the live counts); index k = k
        /// Anki-days later, assuming no reviews happen in between — which is
        /// exactly the case the forecast exists for.
        public var days: [DayCounts]
        /// Raw per-day future-due histogram this forecast was projected
        /// from. Kept so a later write in the same Anki day can re-project
        /// against fresh counts instead of re-running the engine's graphs
        /// RPC once per deck. Optional so pre-existing snapshot files still
        /// decode.
        public var futureDue: [Int: Int]?

        public init(
            rolloverHour: Int,
            dayZero: Date,
            days: [DayCounts],
            futureDue: [Int: Int]? = nil
        ) {
            self.rolloverHour = rolloverHour
            self.dayZero = dayZero
            self.days = days
            self.futureDue = futureDue
        }
    }

    public struct DayCounts: Codable, Sendable, Equatable {
        public var newCount: Int
        public var learnCount: Int
        public var reviewCount: Int

        public init(newCount: Int, learnCount: Int, reviewCount: Int) {
            self.newCount = newCount
            self.learnCount = learnCount
            self.reviewCount = reviewCount
        }
    }

    public static var placeholder: WidgetSnapshot {
        WidgetSnapshot(
            deckId: 0,
            deckName: "All Decks",
            newCount: 5,
            learnCount: 8,
            reviewCount: 22,
            reviewedToday: 18,
            streak: 7,
            lastSevenDays: [20, 15, 22, 18, 25, 12, 8],
            snapshotDate: Date()
        )
    }
}

// MARK: - Anki day math

/// Anki's day rolls over at a configurable hour (default 4 am), so "which
/// day is it" must never use calendar midnight.
public enum AnkiDay {
    /// Start of the Anki day containing `date`: the most recent occurrence
    /// of `rolloverHour`.
    public static func start(
        of date: Date, rolloverHour: Int, calendar: Calendar = .current
    ) -> Date {
        let sameDay = calendar.date(
            bySettingHour: rolloverHour, minute: 0, second: 0, of: date
        ) ?? date
        if sameDay <= date { return sameDay }
        let dayBefore = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return calendar.date(
            bySettingHour: rolloverHour, minute: 0, second: 0, of: dayBefore
        ) ?? date
    }
}

// MARK: - Timeline projection

extension WidgetSnapshot {
    /// (date, snapshot) pairs for a WidgetKit timeline: one entry for `now`,
    /// then one per future Anki-day boundary covered by the forecast. Works
    /// from stale files too — the first entry is computed for whatever
    /// Anki-day `now` actually falls in, so a re-invoked provider self-heals
    /// without polling.
    public func projectedEntries(
        now: Date, calendar: Calendar = .current
    ) -> [(date: Date, snapshot: WidgetSnapshot)] {
        guard let forecast, !forecast.days.isEmpty else { return [(now, self)] }
        let dayZeroStart = AnkiDay.start(
            of: forecast.dayZero, rolloverHour: forecast.rolloverHour, calendar: calendar
        )
        let nowStart = AnkiDay.start(
            of: now, rolloverHour: forecast.rolloverHour, calendar: calendar
        )
        let today = max(
            0, calendar.dateComponents([.day], from: dayZeroStart, to: nowStart).day ?? 0
        )
        var entries = [(date: now, snapshot: projected(day: today, calendar: calendar))]
        let lastDay = forecast.days.count - 1
        if today < lastDay {
            for day in (today + 1)...lastDay {
                guard let boundary = calendar.date(
                    byAdding: .day, value: day, to: dayZeroStart
                ) else { continue }
                entries.append((boundary, projected(day: day, calendar: calendar)))
            }
        }
        return entries
    }

    /// The snapshot as it should render on Anki-day `day` (0 = write day),
    /// assuming no reviews happened after the write.
    func projected(day: Int, calendar: Calendar = .current) -> WidgetSnapshot {
        guard day > 0, let forecast, !forecast.days.isEmpty else { return self }
        let counts = forecast.days[min(day, forecast.days.count - 1)]
        var projected = self
        projected.newCount = counts.newCount
        projected.learnCount = counts.learnCount
        projected.reviewCount = counts.reviewCount
        projected.reviewedToday = 0
        // Same rule as StreakCalculator: a streak survives exactly one
        // boundary, and only if the write day itself had reviews.
        projected.streak = (day == 1 && reviewedToday > 0) ? streak : 0
        let shift = min(day, lastSevenDays.count)
        projected.lastSevenDays =
            Array(lastSevenDays.dropFirst(shift)) + Array(repeating: 0, count: shift)
        projected.snapshotDate =
            calendar.date(byAdding: .day, value: day, to: snapshotDate) ?? snapshotDate
        return projected
    }
}
