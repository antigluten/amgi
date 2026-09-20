//
//  Signposts.swift
//  AppCore
//
//  Created by Vladimir Gusev on 02.09.2026.
//

import OSLog

/// `os_signpost` intervals for the app's named actions.
///
/// Without these an Instruments capture is anonymous: a Time Profiler trace
/// reports session totals ("522 ms in conformance lookups") with no way to
/// attribute a millisecond to opening the deck list or answering a card.
/// Every interval here lands on the **Points of Interest** track, so
/// `xctrace export --xpath '…table[@schema="os-signpost"]'` reads them back
/// and the inspection range can be set to exactly one action.
///
/// Lives beside `Log` in `AppCore` for the same reason: it is engine-free
/// and already linked by every consumer, so routing signposts through it adds
/// no dependency edges.
///
/// Two rules, both load-bearing:
/// - Names are `StaticString` because that is what the signpost API records
///   and what shows up in the `name` column. They are the join key between
///   captures — keep them stable, and put dynamic detail in the message.
/// - The category must be `.pointsOfInterest`. Any other category is recorded
///   but never appears on the Points of Interest track, and the stock
///   template only instruments that one.
public enum AppSignpost {
    private static let signposter = OSSignposter(
        logHandle: OSLog(subsystem: Log.subsystem, category: .pointsOfInterest)
    )

    /// Brackets a synchronous action. The interval closes even if `body` throws.
    public static func measure<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let id = signposter.makeSignpostID()
        let state = signposter.beginInterval(name, id: id)
        defer { signposter.endInterval(name, state) }
        return try body()
    }

    /// Brackets an asynchronous action — the common case here, since every
    /// load in the app is an `async` model method. Closes on throw and on
    /// cancellation, so a cancelled `.task(id:)` does not leave an interval
    /// open forever (an unterminated interval is reported as such and skews
    /// nothing else).
    public static func measure<T>(
        _ name: StaticString,
        _ body: () async throws -> T
    ) async rethrows -> T {
        let id = signposter.makeSignpostID()
        let state = signposter.beginInterval(name, id: id)
        defer { signposter.endInterval(name, state) }
        return try await body()
    }

    /// A zero-duration marker — "this happened here".
    public static func event(_ name: StaticString) {
        signposter.emitEvent(name)
    }
}
