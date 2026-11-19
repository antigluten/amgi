//
//  ReaderDictionarySettingsModel.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 23.06.2026.
//

import Reader
import ReaderDictionary
import Dependencies
import Foundation
import SwiftUI  // Array.move(fromOffsets:toOffset:)

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

    var lacksFrequencyDictionary: Bool {
        !libraryState.frequencyDictionaries.contains(where: \.isEnabled)
    }

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
            actionError = String(localized: "Failed to load library: \(error.localizedDescription)", bundle: .module)
        }
    }

    func handleImport(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            Task { await importArchives(urls) }
        case .failure(let error):
            actionError = String(localized: "Could not select files: \(error.localizedDescription)", bundle: .module)
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
            actionError = String(localized: "Import failed: \(error.localizedDescription)", bundle: .module)
        }
    }

    func toggle(_ info: AppDictionaryInfo) async {
        isBusy = true
        defer { isBusy = false }
        do {
            libraryState = try await dictionary.setEnabled(selectedKind, info.id, !info.isEnabled)
        } catch {
            actionError = String(localized: "Failed to update: \(error.localizedDescription)", bundle: .module)
        }
    }

    func delete(_ info: AppDictionaryInfo) async {
        isBusy = true
        defer { isBusy = false }
        do {
            libraryState = try await dictionary.delete(selectedKind, info.id)
        } catch {
            actionError = String(localized: "Failed to delete: \(error.localizedDescription)", bundle: .module)
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
            actionError = String(localized: "Failed to reorder: \(error.localizedDescription)", bundle: .module)
        }
    }
}
