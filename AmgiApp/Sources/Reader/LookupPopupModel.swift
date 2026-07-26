import AmgiReader
import AmgiReaderDictionary
import Dependencies
import Foundation

/// Dictionary-lookup I/O for the reader popup and its pushed child panes.
/// Owns the one engine dependency so the views carry no `@Dependency`. The
/// user-pref inputs (scan length, max results) stay as `@Shared(.appStorage)`
/// bindings on the views and are passed per call; search-history recording
/// stays on the root view, which keys off `runLookup`'s return value.
@Observable
@MainActor
final class LookupPopupModel {
    var result: DictionaryLookupResult?
    var isLoading = false
    var lookupError: String?

    @ObservationIgnored @Dependency(\.dictionaryLookupClient) private var dictionary

    /// Runs a lookup for `query`. Returns the trimmed query when it produced
    /// a non-empty result (so the caller can record search history), or nil
    /// for empty input, empty results, or failure.
    @discardableResult
    func runLookup(query: String, maxResults: Int, scanLength: Int) async -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            result = nil
            return nil
        }
        isLoading = true
        lookupError = nil
        defer { isLoading = false }
        do {
            let lookup = try await dictionary.lookup(trimmed, maxResults, scanLength)
            result = lookup
            return lookup.entries.isEmpty ? nil : trimmed
        } catch {
            lookupError = error.localizedDescription
            result = nil
            return nil
        }
    }
}
