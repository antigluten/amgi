//
//  DuplicatesReloadTests.swift
//  BrowseFeatureTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import AnkiClients
import AnkiKit
import Dependencies
import Testing
@testable import BrowseFeature

@Suite("Duplicates reload")
@MainActor
struct DuplicatesReloadTests {

    private nonisolated static let group = DuplicateGroup(
        notetypeID: NotetypeID(1),
        value: "neko",
        noteIDs: [NoteID(1), NoteID(2)]
    )

    private nonisolated static func note(_ id: Int64) -> NoteRecord {
        NoteRecord(
            id: NoteID(id),
            guid: "g\(id)",
            mid: NotetypeID(1),
            mod: 100,
            tags: "",
            flds: "neko",
            sfld: "neko",
            csum: 0
        )
    }

    @Test("a reload refetches the notes of a group that was already open")
    func reloadKeepsOpenGroupPopulated() async {
        await withDependencies {
            $0.noteClient.findDuplicates = { [Self.group] }
            $0.noteClient.fetch = { Self.note($0.rawValue) }
        } operation: {
            let model = DuplicatesModel()
            await model.load()
            await model.loadNotes(for: Self.group)
            #expect(model.notesByGroup[Self.group.id]?.count == 2)

            await model.load()

            #expect(
                model.notesByGroup[Self.group.id]?.count == 2,
                "reload dropped the open group's notes — the screen renders it open and empty"
            )
        }
    }

    @Test("a reload does not fetch notes for groups nobody opened")
    func reloadLeavesUnopenedGroupsAlone() async {
        await withDependencies {
            $0.noteClient.findDuplicates = { [Self.group] }
            $0.noteClient.fetch = { _ in
                Issue.record("fetched notes for a group that was never expanded")
                return nil
            }
        } operation: {
            let model = DuplicatesModel()
            await model.load()
            await model.load()

            #expect(model.notesByGroup.isEmpty)
        }
    }

    @Test("an overlapping load discards its own stale result")
    func overlappingLoadDiscardsStaleResult() async {
        let stale = DuplicateGroup(notetypeID: NotetypeID(1), value: "neko", noteIDs: [NoteID(1), NoteID(2)])
        let fresh = DuplicateGroup(notetypeID: NotetypeID(2), value: "inu", noteIDs: [NoteID(3), NoteID(4)])
        let gate = LoadGate()

        await withDependencies {
            $0.noteClient.findDuplicates = {
                if await gate.claimFirstCall() {
                    await gate.waitForRelease()
                    return [stale]
                }
                return [fresh]
            }
        } operation: {
            let model = DuplicatesModel()
            let staleLoad = Task { await model.load() }
            await gate.waitUntilFirstCallStarted()
            await model.load()
            await gate.release()
            await staleLoad.value

            guard case .loaded(let groups) = model.state else {
                Issue.record("expected the fresh load's groups, got \(model.state)")
                return
            }
            #expect(groups == [fresh])
        }
    }

    @Test("an overlapping load discards a stale note restore")
    func overlappingLoadDiscardsStaleNoteRestore() async {
        let gate = NoteFetchGate()

        await withDependencies {
            $0.noteClient.findDuplicates = { [Self.group] }
            $0.noteClient.fetch = { id in
                await gate.gateThirdCall()
                return Self.note(id.rawValue)
            }
        } operation: {
            let model = DuplicatesModel()
            await model.load()
            await model.loadNotes(for: Self.group)
            #expect(model.notesByGroup[Self.group.id]?.count == 2)

            let staleLoad = Task { await model.load() }
            await gate.waitUntilThirdCallStarted()
            await model.load()
            await gate.release()
            await staleLoad.value

            #expect(
                model.notesByGroup[Self.group.id] == nil,
                "the stale reload's restore wrote pre-refresh records over the fresh reload"
            )
        }
    }
}

private actor LoadGate {
    private var callCount = 0
    private var released = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func claimFirstCall() -> Bool {
        callCount += 1
        guard callCount == 1 else { return false }
        startContinuation?.resume()
        startContinuation = nil
        return true
    }

    func waitUntilFirstCallStarted() async {
        guard callCount == 0 else { return }
        await withCheckedContinuation { startContinuation = $0 }
    }

    func waitForRelease() async {
        guard !released else { return }
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private actor NoteFetchGate {
    private var callCount = 0
    private var released = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func gateThirdCall() async {
        callCount += 1
        guard callCount == 3 else { return }
        startContinuation?.resume()
        startContinuation = nil
        guard !released else { return }
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func waitUntilThirdCallStarted() async {
        guard callCount < 3 else { return }
        await withCheckedContinuation { startContinuation = $0 }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
