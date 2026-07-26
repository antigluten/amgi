public import Foundation

public extension Date {
    /// Conversion to the Anki backend's millisecond-since-epoch timestamp
    /// format used in `CardAnswer.answered_at_millis`,
    /// `ComputeFsrsParamsRequest.ignore_revlogs_before_ms`, etc.
    var ankiMillis: Int64 { Int64(timeIntervalSince1970 * 1000) }
}
