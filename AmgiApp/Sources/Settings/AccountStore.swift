import Foundation
import Observation

/// One Anki profile. Each profile owns an isolated collection
/// (`<appSupport>/AnkiCollection/<id>/collection.anki2`) and per-profile
/// sync prefs (already scoped via `SyncPreferences.currentProfileID()`).
struct AmgiAccount: Identifiable, Hashable, Codable {
    /// Filesystem-safe slug used for the per-profile directory and as
    /// the value of `amgi.selectedUser` (the existing scoping anchor).
    let id: String
    /// User-visible display name. Free text; the slug is derived once
    /// at create-time and never renamed (would orphan the directory).
    var displayName: String
    /// When the user first created this profile. Used for sort + the
    /// "since X" line in the picker.
    let createdAt: Date

    static let defaultID = "default"
    static let defaultName = "Default"

    static func newDefault() -> AmgiAccount {
        AmgiAccount(id: defaultID, displayName: defaultName, createdAt: .now)
    }
}

/// Persistent profile registry. The list of accounts and the current
/// selection both live in `UserDefaults`; per-profile state (collection,
/// sync prefs) lives elsewhere and is keyed off `AmgiAccount.id`.
///
/// Switching active profiles requires a relaunch — the app's
/// `AnkiBackend` is wired at startup with one collection path, and
/// rewiring all `@Dependency`-injected clients mid-session is fraught.
/// `pendingSwitchID` records the user's choice; on next cold start the
/// bootstrap reads it and opens the corresponding collection.
@MainActor
@Observable
final class AccountStore {
    static let shared = AccountStore()

    private static let accountsKey = "amgi.accounts"
    private static let selectedKey = "amgi.selectedUser"
    private static let pendingKey = "amgi.pendingSelectedUser"

    private(set) var accounts: [AmgiAccount]
    private(set) var selectedID: String
    /// When set, the next cold start switches to this profile and
    /// clears the pending value. UI shows a "restart to apply" banner.
    private(set) var pendingSwitchID: String?

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
        self.pendingSwitchID = defaults.string(forKey: Self.pendingKey)

        // Backfill: ensure the selected ID exists in the list.
        if !accounts.contains(where: { $0.id == selectedID }) {
            selectedID = accounts.first?.id ?? AmgiAccount.defaultID
        }
        persistAccounts()
        persistSelection()
    }

    var current: AmgiAccount {
        accounts.first(where: { $0.id == selectedID }) ?? accounts[0]
    }

    /// Adds a new profile. Returns the canonical id used (slug derived
    /// from displayName). Throws if the slug collides with an existing
    /// profile or is empty after sanitization.
    @discardableResult
    func add(displayName: String) throws -> AmgiAccount {
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
    func remove(_ account: AmgiAccount, deleteFiles: Bool) throws {
        guard accounts.count > 1 else { throw AccountStoreError.cannotDeleteLast }
        guard account.id != selectedID else { throw AccountStoreError.cannotDeleteActive }
        accounts.removeAll { $0.id == account.id }
        persistAccounts()
        if deleteFiles {
            let dir = Self.profileDirectory(for: account.id)
            try? FileManager.default.removeItem(at: dir)
        }
    }

    /// Schedules a profile switch to apply on next cold start.
    /// `clearPending()` aborts.
    func scheduleSwitch(to account: AmgiAccount) {
        pendingSwitchID = account.id
        UserDefaults.standard.set(account.id, forKey: Self.pendingKey)
    }

    func clearPending() {
        pendingSwitchID = nil
        UserDefaults.standard.removeObject(forKey: Self.pendingKey)
    }

    /// Called once at app bootstrap. If a pending switch is queued,
    /// promotes it to the active selection and clears the pending key.
    /// Returns the profile to open this launch.
    func consumePendingSwitch() -> AmgiAccount {
        if let pending = pendingSwitchID,
           let target = accounts.first(where: { $0.id == pending }) {
            selectedID = target.id
            persistSelection()
            clearPending()
            return target
        }
        return current
    }

    // MARK: - Filesystem helpers

    /// Per-profile collection directory. Files inside follow Anki's
    /// layout: `collection.anki2`, `media/`, `media.db`.
    static func profileDirectory(for id: String) -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("AnkiCollection", isDirectory: true)
            .appendingPathComponent(id, isDirectory: true)
    }

    /// One-time migration on first multi-profile launch: if there's a
    /// legacy `AnkiCollection/collection.anki2` outside any profile
    /// dir, move it into the default profile's directory.
    static func migrateLegacyCollectionIfNeeded() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let legacyRoot = appSupport.appendingPathComponent("AnkiCollection", isDirectory: true)
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

    private func persistAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: Self.accountsKey)
        }
    }

    private func persistSelection() {
        UserDefaults.standard.set(selectedID, forKey: Self.selectedKey)
    }

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
