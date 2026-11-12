public import Foundation

extension AnkiDay {
    public static func shouldRefreshOnResume(
        lastLoad: Date, now: Date, rolloverHour: Int?, calendar: Calendar = .current
    ) -> Bool {
        guard let rolloverHour else { return true }
        return start(of: now, rolloverHour: rolloverHour, calendar: calendar)
            > start(of: lastLoad, rolloverHour: rolloverHour, calendar: calendar)
    }
}
