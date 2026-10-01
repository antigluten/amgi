import Dependencies
import Foundation
import Reader
import ReaderDictionary
import Testing
@testable import ReaderFeature

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LookupPopupConcurrencyTests {
    @Test(arguments: [false, true], [false, true])
    func latestRequestOwnsPopup(olderFails: Bool, olderFinishesFirst: Bool) async throws {
        let requests = PendingLookups()
        let model = withDependencies {
            $0.dictionaryLookupClient.lookup = { query, _, _ in try await requests.lookup(query) }
        } operation: { LookupPopupModel() }

        let older = Task { await model.runLookup(query: "先", maxResults: 1, scanLength: 1) }
        try await requests.waitForCount(1)
        let latest = Task { await model.runLookup(query: "先生", maxResults: 1, scanLength: 2) }
        try await requests.waitForCount(2)
        if olderFinishesFirst {
            await requests.finish(0, fails: olderFails)
            #expect(await older.value == nil)
            #expect(model.isLoading)
            #expect(model.result == nil)
            #expect(model.lookupError == nil)
        }
        await requests.finish(1)
        #expect(await latest.value == "先生")
        if !olderFinishesFirst {
            await requests.finish(0, fails: olderFails)
            #expect(await older.value == nil)
        }
        #expect(model.result?.entries.first?.term == "先生")
        #expect(model.result?.query == "先生")
        #expect(model.lookupError == nil)
        #expect(!model.isLoading)
    }

    @Test func clearingQueryInvalidatesPendingResult() async throws {
        let requests = PendingLookups()
        let model = withDependencies {
            $0.dictionaryLookupClient.lookup = { query, _, _ in try await requests.lookup(query) }
        } operation: { LookupPopupModel() }
        let pending = Task { await model.runLookup(query: "先", maxResults: 1, scanLength: 1) }
        try await requests.waitForCount(1)
        #expect(await model.runLookup(query: " \n ", maxResults: 1, scanLength: 1) == nil)
        #expect(!model.isLoading)
        await requests.finish(0)
        #expect(await pending.value == nil)
        #expect(model.result == nil)
        #expect(model.lookupError == nil)
    }
}

private actor PendingLookups {
    private var pending: [(String, CheckedContinuation<DictionaryLookupResult, any Error>)] = []

    func lookup(_ query: String) async throws -> DictionaryLookupResult {
        try await withCheckedThrowingContinuation { pending.append((query, $0)) }
    }

    func waitForCount(_ count: Int) async throws {
        for _ in 0..<100 {
            if pending.count == count { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw CocoaError(.fileReadUnknown)
    }

    func finish(_ index: Int, fails: Bool = false) {
        let (query, continuation) = pending[index]
        if fails {
            continuation.resume(throwing: CocoaError(.fileReadUnknown))
        } else {
            continuation.resume(returning: DictionaryLookupResult(
                query: query, entries: [DictionaryLookupEntry(term: query)]
            ))
        }
    }
}
