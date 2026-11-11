public import Foundation
public import SwiftUI

extension AnkiDay {
    /// True when the app returns from background into a later Anki day than
    /// the one its on-screen counts were loaded in.
    public static func shouldRefreshOnResume(
        from old: ScenePhase, to new: ScenePhase,
        lastLoad: Date, now: Date, rolloverHour: Int, calendar: Calendar = .current
    ) -> Bool {
        guard old == .background, new != .background else { return false }
        return start(of: now, rolloverHour: rolloverHour, calendar: calendar)
            > start(of: lastLoad, rolloverHour: rolloverHour, calendar: calendar)
    }
}
