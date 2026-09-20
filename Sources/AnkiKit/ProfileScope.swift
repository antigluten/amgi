//
//  ProfileScope.swift
//  AnkiKit
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import Foundation

/// The single anchor every per-profile scope in the app keys off.
///
/// Keychain items, sync preferences, reader-dictionary storage and
/// `AccountStore` all scope themselves by the value stored under this key.
/// It used to be spelled out independently in four modules; a typo in any
/// one of them silently de-scopes that subsystem from the active profile,
/// which is exactly the shared-login bug `KeychainProfileScopingTests`
/// exists to guard against.
///
/// Lives in `AnkiKit` because that is the lowest module both `AnkiSync`
/// (KeychainHelper) and `AppCore` (AccountStore, ReviewPreferences)
/// already depend on. `ReaderDictionary` is the one holdout — its
/// package has no edge to AnkiBridge — so it carries a local copy that
/// points back here.
public enum ProfileScope: Sendable {
    /// UserDefaults key holding the selected profile's id.
    public static let anchorKey = "amgi.selectedUser"

    /// Profile id used when no selection has been made, and by processes
    /// with no profile registry of their own (the watch app).
    public static let defaultID = "default"

    /// The active profile id as seen by this process. Processes with no
    /// profile registry of their own (the watch app) resolve to `defaultID`.
    public static func current() -> String {
        UserDefaults.standard.string(forKey: anchorKey) ?? defaultID
    }
}
