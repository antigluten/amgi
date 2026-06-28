public import AmgiReader
public import Dependencies
import DependenciesMacros
public import Foundation

/// DI surface for offline dictionary lookups. Matches DreamAfar's contract
/// 1:1 so the future full-port slots in cleanly: async lookup with a
/// scan-length window, separate styles loader, media-file resolver for
/// dictionary-bundled images/audio, and library management
/// (import / update / enable / delete).
@DependencyClient
public struct DictionaryLookupClient: Sendable {
    public var lookup: @Sendable (_ text: String, _ maxResults: Int, _ scanLength: Int) async throws -> DictionaryLookupResult
    public var loadStyles: @Sendable () async throws -> [String: String]
    public var mediaFile: @Sendable (_ dictionary: String, _ mediaPath: String) async throws -> Data
    public var loadState: @Sendable () async throws -> AppDictionaryLibraryState
    public var importArchives: @Sendable (_ urls: [URL], _ kind: AppDictionaryKind) async throws -> AppDictionaryLibraryState
    public var importRecommended: @Sendable () async throws -> AppDictionaryLibraryState
    public var updateDictionaries: @Sendable () async throws -> AppDictionaryLibraryState
    public var setEnabled: @Sendable (_ kind: AppDictionaryKind, _ dictionaryID: String, _ enabled: Bool) async throws -> AppDictionaryLibraryState
    public var delete: @Sendable (_ kind: AppDictionaryKind, _ dictionaryID: String) async throws -> AppDictionaryLibraryState
    /// Re-orders the dictionaries of `kind` according to `dictionaryIDs`.
    /// IDs not present in the list keep their relative order and append
    /// after the explicitly-ordered prefix; unknown IDs are ignored.
    public var reorder: @Sendable (_ kind: AppDictionaryKind, _ dictionaryIDs: [String]) async throws -> AppDictionaryLibraryState
}

extension DictionaryLookupClient: TestDependencyKey {
    public static let testValue = DictionaryLookupClient(
        lookup: { text, _, _ in
            DictionaryLookupResult(query: text, entries: [], isPlaceholder: false)
        },
        loadStyles: { [:] },
        mediaFile: { _, _ in Data() },
        loadState: { .empty },
        importArchives: { _, _ in .empty },
        importRecommended: { .empty },
        updateDictionaries: { .empty },
        setEnabled: { _, _, _ in .empty },
        delete: { _, _ in .empty },
        reorder: { _, _ in .empty }
    )
}

extension DependencyValues {
    public var dictionaryLookupClient: DictionaryLookupClient {
        get { self[DictionaryLookupClient.self] }
        set { self[DictionaryLookupClient.self] = newValue }
    }
}
