import Foundation
import Testing
@testable import AppCore

@Suite struct ResumeRefreshTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        DateComponents(
            calendar: calendar, year: 2026, month: 7, day: day,
            hour: hour, minute: minute, second: second
        ).date!
    }

    private func should(lastLoad: Date, now: Date, hour: Int? = 4) -> Bool {
        AnkiDay.shouldRefreshOnResume(
            lastLoad: lastLoad, now: now, rolloverHour: hour, calendar: calendar
        )
    }

    @Test func sameAnkiDayDoesNotRefresh() {
        #expect(!should(lastLoad: date(10, 5), now: date(11, 3)))
    }

    @Test func afterRolloverRefreshes() {
        #expect(should(lastLoad: date(10, 22), now: date(11, 5)))
    }

    @Test func exactlyAtRolloverRefreshes() {
        #expect(should(lastLoad: date(10, 22), now: date(11, 4)))
    }

    @Test func oneSecondBeforeRolloverDoesNotRefresh() {
        #expect(!should(lastLoad: date(10, 22), now: date(11, 3, 59, 59)))
    }

    @Test func multiDayGapRefreshes() {
        #expect(should(lastLoad: date(10, 22), now: date(14, 12)))
    }

    @Test func unknownRolloverHourRefreshes() {
        #expect(should(lastLoad: date(10, 5), now: date(10, 6), hour: nil))
    }
}
