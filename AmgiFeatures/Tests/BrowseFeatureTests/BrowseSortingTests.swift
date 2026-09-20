//
//  BrowseSortingTests.swift
//  BrowseFeatureTests
//
//  Created by Vladimir Gusev on 08.08.2026.
//

import AnkiClients
import AnkiKit
import Dependencies
import Testing
@testable import BrowseFeature

/// `sortedNotes` is stored rather than computed so `body` doesn't re-sort the
/// whole list on every pass. That makes the `didSet` hooks that keep it in
/// sync load-bearing — these tests are what catch it if one stops firing.
@Suite("BrowseModel sorting")
@MainActor
struct BrowseSortingTests {

    private func note(_ id: Int64, sfld: String, mod: Int64, mid: Int64 = 1) -> NoteRecord {
        NoteRecord(
            id: NoteID(id),
            guid: "g\(id)",
            mid: NotetypeID(mid),
            mod: mod,
            tags: "",
            flds: "",
            sfld: sfld,
            csum: 0
        )
    }

    @Test("assigning notes populates sortedNotes")
    func assigningNotesPopulatesSorted() {
        let model = BrowseModel()
        #expect(model.sortedNotes.isEmpty)

        model.notes = [note(1, sfld: "b", mod: 100)]

        #expect(model.sortedNotes.count == 1)
    }

    @Test("default order is newest first")
    func defaultOrderIsNewestFirst() {
        let model = BrowseModel()
        model.notes = [
            note(1, sfld: "old", mod: 100),
            note(2, sfld: "new", mod: 300),
            note(3, sfld: "mid", mod: 200),
        ]

        #expect(model.sortedNotes.map(\.sfld) == ["new", "mid", "old"])
    }

    @Test("changing sortOrder re-sorts immediately")
    func changingSortOrderResorts() {
        let model = BrowseModel()
        model.notes = [
            note(1, sfld: "Charlie", mod: 300),
            note(2, sfld: "alpha", mod: 200),
            note(3, sfld: "Bravo", mod: 100),
        ]

        model.sortOrder = .titleAsc

        // Case-insensitive, so lowercase "alpha" leads.
        #expect(model.sortedNotes.map(\.sfld) == ["alpha", "Bravo", "Charlie"])
    }

    @Test("appending a page keeps sortedNotes in sync")
    func appendingKeepsSortedInSync() {
        let model = BrowseModel()
        model.notes = [note(1, sfld: "first", mod: 100)]
        model.notes.append(note(2, sfld: "second", mod: 500))

        #expect(model.sortedNotes.count == 2)
        #expect(model.sortedNotes.first?.sfld == "second")
    }

    @Test("replacing a stub in place refreshes sortedNotes")
    func replacingStubRefreshesSorted() {
        let model = BrowseModel()
        model.notes = [note(1, sfld: "Loading...", mod: 100)]
        model.notes[0] = note(1, sfld: "resolved", mod: 100)

        #expect(model.sortedNotes.first?.sfld == "resolved")
    }

    @Test("notetype names arriving late re-sort a template-ordered list")
    func lateNotetypeNamesResort() {
        let model = BrowseModel()
        model.sortOrder = .templateAsc
        model.notes = [
            note(1, sfld: "one", mod: 100, mid: 1),
            note(2, sfld: "two", mod: 200, mid: 2),
        ]

        // Names load after the search completes; "Basic" (mid 2) must overtake
        // "Cloze" (mid 1) once they land.
        model.notetypeNames = [NotetypeID(1): "Cloze", NotetypeID(2): "Basic"]

        #expect(model.sortedNotes.map(\.sfld) == ["two", "one"])
    }

    @Test("a stub fill patches sortedNotes without reordering it")
    func stubFillPatchesWithoutReordering() async {
        let resolved = note(1, sfld: "Zebra", mod: 300)
        await withDependencies {
            $0.noteClient.fetch = { _ in resolved }
        } operation: {
            let model = BrowseModel()
            model.sortOrder = .titleAsc
            model.notes = [
                note(1, sfld: "Loading...", mod: 300),
                note(2, sfld: "Mango", mod: 200),
            ]
            // "Loading..." sorts ahead of "Mango" — that's the on-screen order.
            #expect(model.sortedNotes.map(\.sfld) == ["Loading...", "Mango"])

            await model.fetchNoteDetails(id: NoteID(1))

            // The resolved text lands, but the row holds its position:
            // re-sorting here would move it under the user's finger mid-scroll,
            // and would cost a full sort per row filled during that scroll.
            #expect(model.sortedNotes.map(\.sfld) == ["Zebra", "Mango"])
            #expect(model.notes.map(\.sfld) == ["Zebra", "Mango"])
        }
    }

    @Test("clearing notes clears sortedNotes")
    func clearingNotesClearsSorted() {
        let model = BrowseModel()
        model.notes = [note(1, sfld: "a", mod: 100)]
        model.notes = []

        #expect(model.sortedNotes.isEmpty)
    }
}
