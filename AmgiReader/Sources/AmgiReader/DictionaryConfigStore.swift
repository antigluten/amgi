public import Dependencies
import DependenciesMacros
public import Foundation

/// Abstract key-value JSON store the dictionary engine writes its
/// cross-device library config to. The engine itself never knows whether
/// reads/writes go to the Anki collection config, an iCloud KVS, or an
/// in-memory test fake — the host app injects a concrete realization at
/// runtime.
///
/// Boundary stays at raw `Data?` so this module pulls in no extra
/// Codable/Encodable surface from the host. The dictionary runtime
/// layers its own encode/decode on top.
@DependencyClient
public struct DictionaryConfigStore: Sendable {
    public var load: @Sendable (_ key: String) async throws -> Data?
    public var save: @Sendable (_ json: Data, _ key: String) async throws -> Void
    public var remove: @Sendable (_ key: String) async throws -> Void
}

extension DictionaryConfigStore: TestDependencyKey {
    /// The test default returns nil for every read and discards every
    /// write, matching DependenciesMacros's "unimplemented" convention
    /// without making tests trip over uninitialized closures.
    public static let testValue = DictionaryConfigStore(
        load: { _ in nil },
        save: { _, _ in },
        remove: { _ in }
    )
}

extension DictionaryConfigStore: DependencyKey {
    /// In-memory default so the dictionary engine can build and run in
    /// previews / SPM tests / lightweight runs without an Anki backend
    /// attached. The host app overrides this with `withDependencies` or
    /// `prepareDependencies` at startup, pointing it at the real
    /// collection-config store.
    public static let liveValue: DictionaryConfigStore = {
        let storage = MemoryDictionaryConfigStorage()
        return DictionaryConfigStore(
            load: { key in await storage.load(key: key) },
            save: { value, key in await storage.save(value, key: key) },
            remove: { key in await storage.remove(key: key) }
        )
    }()
}

extension DependencyValues {
    public var dictionaryConfigStore: DictionaryConfigStore {
        get { self[DictionaryConfigStore.self] }
        set { self[DictionaryConfigStore.self] = newValue }
    }
}

/// Lock-protected dictionary used as the in-memory `liveValue` default.
/// Actor-shaped so concurrent loads/saves serialize without explicit
/// locking at the call site.
private actor MemoryDictionaryConfigStorage {
    private var storage: [String: Data] = [:]

    func load(key: String) -> Data? { storage[key] }
    func save(_ value: Data, key: String) { storage[key] = value }
    func remove(key: String) { storage.removeValue(forKey: key) }
}
