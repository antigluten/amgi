public import Foundation
import Security

public enum KeychainHelper: Sendable {
    private static let service = "com.ankiapp.sync"
    private static let hostKeyAccount = "sync-host-key"
    private static let usernameAccount = "sync-username"
    private static let endpointAccount = "sync-endpoint"
    private static let currentEndpointAccount = "sync-current-endpoint"

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
        let data = Data(value.utf8)
        // Delete existing item first to avoid duplicates
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func load(account: String) -> String? {
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

    private static func delete(account: String) {
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
