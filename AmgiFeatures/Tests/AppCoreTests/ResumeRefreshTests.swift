import Foundation
import SwiftUI
import Testing
@testable import AppCore

@Suite struct ResumeRefreshTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 7, day: day, hour: hour).date!
    }

    private func should(
        _ old: ScenePhase, _ new: ScenePhase, lastLoad: Date, now: Date
    ) -> Bool {
        AnkiDay.shouldRefreshOnResume(
            from: old, to: new, lastLoad: lastLoad, now: now, rolloverHour: 4, calendar: calendar
        )
    }

    @Test func sameAnkiDayDoesNotRefresh() {
        #expect(!should(.background, .active, lastLoad: date(10, 5), now: date(11, 3)))
    }

    @Test func afterRolloverRefreshes() {
        #expect(should(.background, .active, lastLoad: date(10, 22), now: date(11, 5)))
    }

    @Test func nonBackgroundTransitionsDoNotRefresh() {
        let late = date(11, 5), early = date(10, 22)
        #expect(!should(.inactive, .active, lastLoad: early, now: late))
        #expect(!should(.active, .inactive, lastLoad: early, now: late))
        #expect(!should(.active, .background, lastLoad: early, now: late))
    }
}
