//
//  KeychainHelper.swift
//  AnkiSync
//
//  Created by Vladimir Gusev on 27.03.2026.
//

public import Foundation
import AnkiKit
import Security

/// Sync identity (endpoint, host key, username, shard) is **per-profile**:
/// every item is stored under `<base>__<profileID>`, where the profile id is
/// the same `amgi.selectedUser` anchor that scopes sync prefs. Processes
/// without a profile registry (the watch app) resolve to "default".
public enum KeychainHelper: Sendable {
    private static let service = "com.ankiapp.sync"
    private static let hostKeyAccount = "sync-host-key"
    private static let usernameAccount = "sync-username"
    private static let endpointAccount = "sync-endpoint"
    private static let currentEndpointAccount = "sync-current-endpoint"
    private static let defaultProfileID = ProfileScope.defaultID

    private static func currentProfileID() -> String {
        ProfileScope.current()
    }

    /// Deletes every sync item belonging to `profileID`.
    ///
    /// Takes the id explicitly rather than reading the current anchor,
    /// because the caller that needs this — removing a profile — is by
    /// definition not operating on the selected profile.
    public static func deleteAll(forProfile profileID: String) {
        for base in [hostKeyAccount, usernameAccount, endpointAccount, currentEndpointAccount] {
            deleteRaw(account: "\(base)__\(profileID)")
        }
    }

    private static func scoped(_ base: String) -> String {
        "\(base)__\(currentProfileID())"
    }

    // MARK: - Host Key

    public static func saveHostKey(_ key: String) throws {
        try save(account: hostKeyAccount, value: key)
    }

    public static func loadHostKey() -> String? {
        load(account: hostKeyAccount)
    }

    public static func deleteHostKey() {
        delete(account: hostKeyAccount)
    }

    // MARK: - Username

    public static func saveUsername(_ username: String) throws {
        try save(account: usernameAccount, value: username)
    }

    public static func loadUsername() -> String? {
        load(account: usernameAccount)
    }

    public static func deleteUsername() {
        delete(account: usernameAccount)
    }

    // MARK: - Endpoint

    public static func saveEndpoint(_ url: String) throws {
        try save(account: endpointAccount, value: url)
    }

    public static func loadEndpoint() -> String? {
        load(account: endpointAccount)
    }

    public static func deleteEndpoint() {
        delete(account: endpointAccount)
    }

    // MARK: - Current Endpoint
    //
    // Last shard URL the sync server redirected us to. AnkiWeb pins
    // upload/download to a specific shard (e.g. sync5.ankiweb.net) and only
    // emits the redirect on the meta path, so subsequent FullUploadOrDownload
    // calls must already point at the shard. Kept separate from the
    // user-configured endpoint so changing servers can reset it cleanly.

    public static func saveCurrentEndpoint(_ url: String) throws {
        try save(account: currentEndpointAccount, value: url)
    }

    public static func loadCurrentEndpoint() -> String? {
        load(account: currentEndpointAccount)
    }

    public static func deleteCurrentEndpoint() {
        delete(account: currentEndpointAccount)
    }

    // MARK: - Internal

    private static func save(account: String, value: String) throws {
        try saveRaw(account: scoped(account), value: value)
    }

    private static func load(account: String) -> String? {
        if let value = loadRaw(account: scoped(account)) { return value }
        // Legacy migration: pre-profile items were stored unscoped and belong
        // to the original "default" profile. Move on first read from default;
        // other profiles must not inherit them — that was the shared-login bug.
        guard currentProfileID() == defaultProfileID,
              let legacy = loadRaw(account: account) else { return nil }
        // Only retire the legacy item once the scoped copy is confirmed
        // written — deleting it unconditionally destroyed a working login
        // whenever the save failed.
        do {
            try saveRaw(account: scoped(account), value: legacy)
            deleteRaw(account: account)
        } catch {
            // Keep the legacy item; migration retries on the next read.
        }
        return legacy
    }

    private static func delete(account: String) {
        deleteRaw(account: scoped(account))
    }

    private static func saveRaw(account: String, value: String) throws {
        let data = Data(value.utf8)
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        // Update in place when the item exists. The previous
        // delete-then-add lost the old value outright if SecItemAdd then
        // failed, and every caller discards the error — so a failed write
        // silently wiped the endpoint or host key and sync fell through to
        // an empty endpoint string.
        let updateStatus = SecItemUpdate(
            identity as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.saveFailed(updateStatus)
        }

        var insert = identity
        insert[kSecValueData as String] = data
        // ThisDeviceOnly: the sync host key is re-obtainable by logging in
        // again, so there is no reason to let it ride an encrypted backup
        // onto a different device.
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func loadRaw(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteRaw(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public enum KeychainError: Error, Sendable {
    case saveFailed(OSStatus)
}
