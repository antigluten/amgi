//
//  AppGroup.swift
//  AppCore
//
//  Created by Vladimir Gusev on 20.08.2026.
//

public import Foundation

/// The App Group container shared by the app, the widget extension, and the
/// watch.
///
/// Canonical for everything that can see `AppCore`. Two copies of the
/// identifier live outside that reach and must be kept in sync by hand:
/// `Theme/UserDefaults+AppGroup.swift` (Theme is deliberately
/// dependency-free, so it cannot import this) and the two `.entitlements`
/// files. A mismatch silently splits the container in two, and the symptom —
/// the widget reading an empty store — looks nothing like a typo.
public enum AppGroup: Sendable {
    public static let identifier = "group.com.amgiapp"

    /// Shared defaults, falling back to `.standard` when the entitlement is
    /// missing, which is the case in previews and unit tests.
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
