import AmgiReader
import AmgiReaderDictionary
import Dependencies
import Foundation

/// Dictionary-library I/O for the reader settings screen. Owns the engine
/// dependency plus the library list, selected kind, busy flag, and last
/// action error so the view carries no `@Dependency`. The lookup-behavior
/// and audio prefs stay as `@Shared(.appStorage)` bindings on the view.
@Observable
@MainActor
final class ReaderDictionarySettingsModel {
    var libraryState: AppDictionaryLibraryState = .empty
    var selectedKind: AppDictionaryKind = .term
    var isBusy = false
    var actionError: String?

    @ObservationIgnored @Dependency(\.dictionaryLookupClient) private var dictionary

    var dictionaries: [AppDictionaryInfo] {
        switch selectedKind {
        case .term: return libraryState.termDictionaries
        case .frequency: return libraryState.frequencyDictionaries
        case .pitch: return libraryState.pitchDictionaries
        }
    }

    func refresh() async {
        do {
            libraryState = try await dictionary.loadState()
        } catch {
            actionError = "Failed to load library: \(error.localizedDescription)"
        }
    }

    func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { await importArchives(urls) }
        case .failure(let error):
            actionError = "Could not select files: \(error.localizedDescription)"
        }
    }

    func importArchives(_ urls: [URL]) async {
        isBusy = true
        defer { isBusy = false }
        do {
            // The engine takes the URLs and copies/extracts as needed —
            // host-side security-scoped resource access is its concern,
            // mirroring how DreamAfar's importer drives FileManager.
            libraryState = try await dictionary.importArchives(urls, selectedKind)
        } catch {
            actionError = "Import failed: \(error.localizedDescription)"
        }
    }

    func toggle(_ info: AppDictionaryInfo) async {
        isBusy = true
        defer { isBusy = false }
        do {
            libraryState = try await dictionary.setEnabled(selectedKind, info.id, !info.isEnabled)
        } catch {
            actionError = "Failed to update: \(error.localizedDescription)"
        }
    }

    func delete(_ info: AppDictionaryInfo) async {
        isBusy = true
        defer { isBusy = false }
        do {
            libraryState = try await dictionary.delete(selectedKind, info.id)
        } catch {
            actionError = "Failed to delete: \(error.localizedDescription)"
        }
    }

    func move(from source: IndexSet, to destination: Int) async {
        var ids = dictionaries.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        isBusy = true
        defer { isBusy = false }
        do {
            libraryState = try await dictionary.reorder(selectedKind, ids)
        } catch {
            actionError = "Failed to reorder: \(error.localizedDescription)"
        }
    }
}
