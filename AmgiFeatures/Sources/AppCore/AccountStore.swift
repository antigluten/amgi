//
//  AccountStore.swift
//  AppCore
//
//  Created by Vladimir Gusev on 05.05.2026.
//

public import Foundation
import AnkiKit
import Observation

/// One Anki profile. Each profile owns an isolated collection
/// (`<appSupport>/AnkiCollection/<id>/collection.anki2`) and per-profile
/// sync prefs (already scoped via `SyncPreferences.currentProfileID()`).
public struct AmgiAccount: Identifiable, Hashable, Codable, Sendable {
    /// Filesystem-safe slug used for the per-profile directory and as
    /// the value of `amgi.selectedUser` (the existing scoping anchor).
    public let id: String
    /// User-visible display name. Free text; the slug is derived once
    /// at create-time and never renamed (would orphan the directory).
    public var displayName: String
    /// When the user first created this profile. Used for sort + the
    /// "since X" line in the picker.
    public let createdAt: Date

    public static let defaultID = "default"
    public static let defaultName = "Default"

    public static func newDefault() -> AmgiAccount {
        AmgiAccount(id: defaultID, displayName: defaultName, createdAt: .now)
    }
}

/// Persistent profile registry. The list of accounts and the current
/// selection both live in `UserDefaults`; per-profile state (collection,
/// sync prefs, keychain sync identity) lives elsewhere and is keyed off
/// `AmgiAccount.id` via the `amgi.selectedUser` anchor.
///
/// Switching is in-app: `switchProfile(to:)` (AmgiAppApp.swift) swaps the
/// open collection on the shared backend, calls `select(_:)` to flip the
/// scoping anchor, and the root view re-ids on `selectedID` so the whole
/// UI rebuilds against the new collection.
@MainActor
@Observable
public final class AccountStore {
    public static let shared = AccountStore()

    private static let accountsKey = "amgi.accounts"
    private static let selectedKey = ProfileScope.anchorKey

    public private(set) var accounts: [AmgiAccount]
    public private(set) var selectedID: String

    /// Set when a profile switch could not reopen *any* collection, leaving
    /// the app with nothing open. Surfaced by the root view so the state is
    /// visible rather than presenting as a mysteriously empty app.
    public var switchFailure: String?

    /// Binding projection for the failure alert. SwiftUI wants a `Bool`
    /// binding and the state is an optional message; a get/set closure
    /// `Binding` at the call site allocates on every body evaluation and
    /// defeats comparison, so the projection lives here instead.
    ///
    /// Writing `true` is a no-op: only a failed switch produces a message.
    public var hasSwitchFailure: Bool {
        get { switchFailure != nil }
        set { if !newValue { switchFailure = nil } }
    }

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.accountsKey),
           let decoded = try? JSONDecoder().decode([AmgiAccount].self, from: data),
           !decoded.isEmpty {
            self.accounts = decoded
        } else {
            // First-run: seed with the legacy single-profile setup.
            self.accounts = [.newDefault()]
        }
        self.selectedID = defaults.string(forKey: Self.selectedKey) ?? AmgiAccount.defaultID

        // Backfill: ensure the selected ID exists in the list.
        if !accounts.contains(where: { $0.id == selectedID }) {
            selectedID = accounts.first?.id ?? AmgiAccount.defaultID
        }
        persistAccounts()
        persistSelection()
    }

    public var current: AmgiAccount {
        accounts.first(where: { $0.id == selectedID }) ?? accounts[0]
    }

    /// Adds a new profile. Returns the canonical id used (slug derived
    /// from displayName). Throws if the slug collides with an existing
    /// profile or is empty after sanitization.
    @discardableResult
    public func add(displayName: String) throws -> AmgiAccount {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AccountStoreError.emptyName
        }
        let id = Self.slug(from: trimmed)
        guard !id.isEmpty else { throw AccountStoreError.emptyName }
        if accounts.contains(where: { $0.id == id }) {
            throw AccountStoreError.duplicateName
        }
        let account = AmgiAccount(id: id, displayName: trimmed, createdAt: .now)
        accounts.append(account)
        persistAccounts()
        return account
    }

    /// Removes a profile and (if requested) its on-disk collection.
    /// Refuses to delete the active profile or the last remaining one.
    public func remove(_ account: AmgiAccount, deleteFiles: Bool) throws {
        guard accounts.count > 1 else { throw AccountStoreError.cannotDeleteLast }
        guard account.id != selectedID else { throw AccountStoreError.cannotDeleteActive }
        accounts.removeAll { $0.id == account.id }
        persistAccounts()
        if deleteFiles {
            let dir = Self.profileDirectory(for: account.id)
            try? FileManager.default.removeItem(at: dir)
        }
    }

    /// Marks `account` as the active profile and persists the selection —
    /// this flips the scoping anchor for sync prefs and keychain identity.
    /// Collection close/reopen is the caller's job (`switchProfile(to:)`).
    public func select(_ account: AmgiAccount) {
        guard accounts.contains(where: { $0.id == account.id }) else { return }
        selectedID = account.id
        persistSelection()
    }

    // MARK: - Filesystem helpers

    /// Parent of every profile directory.
    ///
    /// Before multi-profile support this *was* the collection directory, so
    /// anything reaching for it directly is either doing legacy migration or
    /// operating on all profiles at once. Per-profile work wants
    /// `profileDirectory(for:)`.
    public static var collectionRoot: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? URL.applicationSupportDirectory
        return appSupport.appendingPathComponent("AnkiCollection", isDirectory: true)
    }

    /// Per-profile collection directory. Files inside follow Anki's
    /// layout: `collection.anki2`, `media/`, `media.db`.
    public static func profileDirectory(for id: String) -> URL {
        collectionRoot.appendingPathComponent(id, isDirectory: true)
    }

    /// One-time migration on first multi-profile launch: if there's a
    /// legacy `AnkiCollection/collection.anki2` outside any profile
    /// dir, move it into the default profile's directory.
    public static func migrateLegacyCollectionIfNeeded() {
        let legacyRoot = collectionRoot
        let legacyCollection = legacyRoot.appendingPathComponent("collection.anki2")
        let target = profileDirectory(for: AmgiAccount.defaultID)
        let targetCollection = target.appendingPathComponent("collection.anki2")
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyCollection.path),
              !fm.fileExists(atPath: targetCollection.path) else { return }
        try? fm.createDirectory(at: target, withIntermediateDirectories: true)
        for name in ["collection.anki2", "media", "media.db"] {
            let src = legacyRoot.appendingPathComponent(name)
            let dst = target.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path), !fm.fileExists(atPath: dst.path) {
                try? fm.moveItem(at: src, to: dst)
            }
        }
    }

    // MARK: - Persistence

    // MARK: - Slug

    /// Filesystem- and pref-key-safe slug. Lowercased, alphanumerics +
    /// `-_`, collapsed underscores, length-capped. The same rule as
    /// `SyncPreferences.currentProfileID()` so the scoping anchor lines
    /// up.
    static func slug(from name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let lower = name.lowercased()
        let mapped = lower.unicodeScalars.map { Character(allowed.contains($0) ? $0 : "_") }
        let collapsed = String(mapped)
            .components(separatedBy: "_")
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        let trimmed = String(collapsed.prefix(40))
        return trimmed.isEmpty ? "" : trimmed
    }
}

enum AccountStoreError: LocalizedError {
    case emptyName
    case duplicateName
    case cannotDeleteLast
    case cannotDeleteActive

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Profile name can't be empty."
        case .duplicateName: return "A profile with that name already exists."
        case .cannotDeleteLast: return "You need at least one profile."
        case .cannotDeleteActive: return "Switch to another profile before deleting this one."
        }
    }
}

private extension AccountStore {
    func persistAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: Self.accountsKey)
        }
    }

    func persistSelection() {
        UserDefaults.standard.set(selectedID, forKey: Self.selectedKey)
    }
}
