public import Foundation

public extension UserDefaults {
    /// App Group store shared across the iOS app, widget extension, and watch app.
    /// Falls back to `.standard` if the App Group entitlement is missing
    /// (e.g. running unit tests outside the app sandbox), so callers can always
    /// read/write something. Tests should pass in their own `UserDefaults` instance.
    ///
    /// Marked `nonisolated(unsafe)` because `UserDefaults` is documented thread-safe
    /// but not `Sendable`-conforming on this SDK. Required so the widget extension
    /// and watch app (non-main contexts) can read the same store.
    nonisolated(unsafe) static let amgiAppGroup: UserDefaults = {
        let groupId = "group.com.amgiapp"
        return UserDefaults(suiteName: groupId) ?? .standard
    }()
}
