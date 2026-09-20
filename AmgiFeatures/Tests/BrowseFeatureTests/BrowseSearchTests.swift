//
//  BrowseSearchTests.swift
//  BrowseFeatureTests
//
//  Created by Vladimir Gusev on 15.08.2026.
//

import AnkiClients
import AnkiKit
import AnkiServices
import Dependencies
import Testing
import Foundation
@testable import BrowseFeature

/// `performSearch` is driven from `.task(id: model.searchQuery)`, so it gets
/// cancelled and restarted on every keystroke. These tests pin the two
/// cancellation points that make that safe — without them, typing issued one
/// racing backend search per character and the list showed whichever returned
/// last rather than the one the user typed.
@Suite("BrowseModel search")
@MainActor
struct BrowseSearchTests {

    private nonisolated static func note(_ id: Int64, sfld: String, mod: Int64 = 100) -> NoteRecord {
        NoteRecord(
            id: NoteID(id),
            guid: "g\(id)",
            mid: NotetypeID(1),
            mod: mod,
            tags: "",
            flds: "",
            sfld: sfld,
            csum: 0
        )
    }

    /// Counts backend hits across concurrent callers.
    private final class CallLog: @unchecked Sendable {
        private let lock = NSLock()
        private var queries: [String] = []

        func record(_ query: String) {
            lock.lock()
            defer { lock.unlock() }
            queries.append(query)
        }

        var all: [String] {
            lock.lock()
            defer { lock.unlock() }
            return queries
        }
    }

    // MARK: searchQuery

    @Test("searchQuery folds text, deck, and tag into one key")
    func searchQueryFoldsAllFilters() {
        let model = BrowseModel()
        #expect(model.searchQuery.isEmpty)

        model.searchText = "kanji"
        #expect(model.searchQuery == "kanji")

        model.activeTag = "verb"
        #expect(model.searchQuery == "tag:\"verb\" kanji")
    }

    // MARK: Debounce

    @Test("a search cancelled during the debounce never reaches the backend")
    func cancelledDuringDebounceNeverSearches() async {
        let log = CallLog()
        await withDependencies {
            $0.noteClient.search = { query, _ in
                log.record(query)
                return []
            }
        } operation: {
            let model = BrowseModel()
            model.searchText = "abc"

            let task = Task { await model.performSearch() }
            task.cancel()
            await task.value

            #expect(log.all.isEmpty, "cancelled before the debounce elapsed, so no query should have been issued")
        }
    }

    @Test("with the debounce waived the search runs immediately")
    func waivedDebounceSearchesImmediately() async {
        let log = CallLog()
        await withDependencies {
            $0.noteClient.search = { query, _ in
                log.record(query)
                return [Self.note(1, sfld: "hit")]
            }
        } operation: {
            let model = BrowseModel()
            model.searchText = "abc"
            await model.performSearch(debounce: .zero)

            #expect(log.all == ["abc"])
            #expect(model.notes.map(\.sfld) == ["hit"])
            #expect(!model.isLoading)
        }
    }

    // MARK: Stale results

    @Test("a search cancelled mid-flight does not write its results")
    func cancelledMidFlightDoesNotWriteResults() async {
        await withDependencies {
            $0.noteClient.search = { _, _ in
                // Long enough that the cancellation below lands while this is
                // still in flight. Cancellation is not observed here, so the
                // call returns normally and only the post-await guard can stop
                // the write.
                try? await Task.sleep(for: .milliseconds(200))
                return [Self.note(99, sfld: "stale")]
            }
        } operation: {
            let model = BrowseModel()
            model.notes = [Self.note(1, sfld: "current")]
            model.searchText = "abc"

            let task = Task { await model.performSearch(debounce: .zero) }
            try? await Task.sleep(for: .milliseconds(50))
            task.cancel()
            await task.value

            #expect(model.notes.map(\.sfld) == ["current"], "a superseded search must not overwrite the list")
        }
    }

    // MARK: Failure surfacing

    @Test("a failed search is distinguishable from an empty one")
    func failedSearchIsDistinguishable() async {
        struct Boom: Error {}

        await withDependencies {
            $0.noteClient.search = { _, _ in throw Boom() }
        } operation: {
            let model = BrowseModel()
            await model.performSearch(debounce: .zero)

            #expect(model.notes.isEmpty)
            #expect(model.searchFailed)
        }

        await withDependencies {
            $0.noteClient.search = { _, _ in [] }
        } operation: {
            let model = BrowseModel()
            await model.performSearch(debounce: .zero)

            #expect(model.notes.isEmpty)
            #expect(!model.searchFailed, "an empty result set is not a failure")
        }
    }

    @Test("a successful search clears a previous failure")
    func successClearsPreviousFailure() async {
        struct Boom: Error {}

        let shouldThrow = CallLog()
        await withDependencies {
            $0.noteClient.search = { query, _ in
                shouldThrow.record(query)
                if shouldThrow.all.count == 1 { throw Boom() }
                return [Self.note(1, sfld: "ok")]
            }
        } operation: {
            let model = BrowseModel()
            await model.performSearch(debounce: .zero)
            #expect(model.searchFailed)

            await model.performSearch(debounce: .zero)
            #expect(!model.searchFailed)
            #expect(model.notes.map(\.sfld) == ["ok"])
        }
    }

    // MARK: Initial load

    @Test("loadInitial does not search — the keyed task owns that")
    func loadInitialDoesNotSearch() async {
        let log = CallLog()
        await withDependencies {
            $0.noteClient.search = { query, _ in
                log.record(query)
                return []
            }
            $0.deckClient.fetchAll = { [] }
            $0.tagClient.getAllTags = { [] }
            $0.notetypesService.getNotetypeNames = { [] }
        } operation: {
            let model = BrowseModel()
            await model.loadInitial()

            #expect(log.all.isEmpty, "searching here too would issue the first query twice")
        }
    }
}
