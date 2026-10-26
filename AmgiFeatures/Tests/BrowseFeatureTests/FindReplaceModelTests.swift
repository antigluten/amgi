//
//  FindReplaceModelTests.swift
//  BrowseFeatureTests
//
//  Created by Vladimir Gusev on 22.10.2026.
//

import AnkiClients
import AnkiKit
import Dependencies
import Foundation
import Testing
@testable import BrowseFeature

@Suite("FindReplaceModel")
@MainActor
struct FindReplaceModelTests {

    private final class Calls: @unchecked Sendable {
        private let lock = NSLock()
        private var _args: [(ids: [NoteID], search: String, replacement: String, regex: Bool, matchCase: Bool, field: String)] = []
        private var _undos = 0
        var args: [(ids: [NoteID], search: String, replacement: String, regex: Bool, matchCase: Bool, field: String)] {
            lock.withLock { _args }
        }
        var undos: Int { lock.withLock { _undos } }
        func record(_ ids: [NoteID], _ s: String, _ r: String, _ re: Bool, _ mc: Bool, _ f: String) {
            lock.withLock { _args.append((ids, s, r, re, mc, f)) }
        }
        func recordUndo() { lock.withLock { _undos += 1 } }
    }

    private func makeModel(
        ids: [NoteID], calls: Calls, result: Result<Int, any Error> = .success(2), undoFails: Bool = false
    ) -> FindReplaceModel {
        withDependencies {
            $0.noteClient.fieldNamesForNotes = { _ in ["Front", "Back"] }
            $0.noteClient.findAndReplace = { ids, s, r, re, mc, f in
                calls.record(ids, s, r, re, mc, f)
                return try result.get()
            }
            $0.cardClient.undoLast = {
                calls.recordUndo()
                if undoFails { throw CocoaError(.fileReadUnknown) }
            }
            $0.notetypesClient.listAll = { [NotetypeNameId(id: NotetypeID(1), name: "Basic")] }
            $0.notetypesClient.get = { _ in
                Notetype(id: NotetypeID(1), name: "Basic", fields: [
                    .init(name: "Front"), .init(name: "Back"),
                ])
            }
        } operation: {
            FindReplaceModel(noteIDs: ids)
        }
    }

    @Test func emptyFindCannotApply() {
        let model = makeModel(ids: [NoteID(1)], calls: Calls())
        #expect(!model.canApply)
        model.find = "x"
        #expect(model.canApply)
    }

    @Test func applyPassesEveryOptionAndReportsCount() async {
        let calls = Calls()
        let model = makeModel(ids: [NoteID(1), NoteID(2)], calls: calls)
        model.find = "a+"
        model.replacement = "b"
        model.fieldName = "Front"
        model.useRegex = true
        model.matchCase = true
        await model.apply()

        let call = calls.args.first
        #expect(call?.ids == [NoteID(1), NoteID(2)])
        #expect(call?.search == "a+")
        #expect(call?.replacement == "b")
        #expect(call?.regex == true)
        #expect(call?.matchCase == true)
        #expect(call?.field == "Front")
        #expect(model.outcome == .updated(2))
        #expect(model.canUndo)
    }

    @Test func replacementDollarsAreLiteralUnlessRegex() async {
        let calls = Calls()
        let model = makeModel(ids: [], calls: calls)
        model.find = "price"
        model.replacement = "$5 ${1}"
        await model.apply()
        model.useRegex = true
        await model.apply()
        #expect(calls.args.map(\.replacement) == ["$$5 $${1}", "$5 ${1}"])
    }

    @Test func sameInputsCannotBeAppliedTwiceUntilChangedOrUndone() async {
        let calls = Calls()
        let model = makeModel(ids: [NoteID(1)], calls: calls)
        model.find = "x"
        await model.apply()
        #expect(!model.canApply)
        await model.apply()
        #expect(calls.args.count == 1)
        #expect(model.canUndo, "undo stays available while the inputs are unchanged")

        model.matchCase = true
        #expect(model.canApply)
        model.matchCase = false
        #expect(!model.canApply)

        await model.undo()
        #expect(model.canApply)
    }

    @Test func editingDuringApplyRecordsTheInputsThatRan() async {
        final class Box: @unchecked Sendable { var model: FindReplaceModel? }
        let box = Box()
        let model = withDependencies {
            $0.noteClient.findAndReplace = { _, _, _, _, _, _ in
                await MainActor.run { box.model?.find = "dog" }
                return 1
            }
        } operation: {
            FindReplaceModel(noteIDs: [NoteID(1)])
        }
        box.model = model
        model.find = "cat"
        await model.apply()
        #expect(model.canApply, "\"dog\" never ran")
        model.find = "cat"
        #expect(!model.canApply)
    }

    @Test func failedUndoKeepsReplaceBlocked() async {
        let calls = Calls()
        let model = makeModel(ids: [NoteID(1)], calls: calls, undoFails: true)
        model.find = "x"
        await model.apply()
        await model.undo()
        #expect(calls.undos == 1)
        #expect(!model.canUndo)
        #expect(!model.canApply, "the replace is still applied, so identical inputs must stay blocked")
        if case .failed = model.outcome {} else { Issue.record("expected a failed outcome") }
    }

    @Test func zeroMatchesOffersNoUndo() async {
        let model = makeModel(ids: [], calls: Calls(), result: .success(0))
        model.find = "x"
        await model.apply()
        #expect(model.outcome == .updated(0))
        #expect(!model.canUndo)
    }

    @Test func failureSurfacesMessageAndNoUndo() async {
        struct Boom: LocalizedError { var errorDescription: String? { "<pre>bad regex\n</pre>" } }
        let model = makeModel(ids: [], calls: Calls(), result: .failure(Boom()))
        model.find = "("
        await model.apply()
        #expect(model.outcome == .failed("bad regex"))
        #expect(!model.canUndo)
    }

    @Test func undoCallsEngineOnceAndClearsUndo() async {
        let calls = Calls()
        let model = makeModel(ids: [NoteID(1)], calls: calls)
        model.find = "x"
        await model.apply()
        await model.undo()
        await model.undo()
        #expect(calls.undos == 1)
        #expect(model.outcome == .undone)
        #expect(!model.canUndo)
    }

    @Test func selectionFieldNamesComeFromTheNotes() async {
        let model = makeModel(ids: [NoteID(1)], calls: Calls())
        await model.loadFieldNames()
        #expect(model.fieldNames == ["Front", "Back"])
    }

    @Test func wholeCollectionFieldNamesComeFromNotetypes() async {
        let model = makeModel(ids: [], calls: Calls())
        await model.loadFieldNames()
        #expect(model.fieldNames == ["Back", "Front"])
    }
}
