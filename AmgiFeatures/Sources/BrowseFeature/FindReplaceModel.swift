//
//  FindReplaceModel.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 22.10.2026.
//

import AnkiClients
import AnkiKit
import Dependencies
import Foundation

@Observable
@MainActor
final class FindReplaceModel {
    enum Outcome: Equatable {
        case updated(Int)
        case undone
        case failed(String)
    }

    // Empty means the whole collection.
    let noteIDs: [NoteID]
    var fieldNames: [String] = []
    var find = ""
    var replacement = ""
    // Empty means every field.
    var fieldName = ""
    var useRegex = false
    var matchCase = false
    var isWorking = false
    var outcome: Outcome?
    var canUndo = false

    @ObservationIgnored @Dependency(\.noteClient) private var noteClient
    @ObservationIgnored @Dependency(\.cardClient) private var cardClient
    @ObservationIgnored @Dependency(\.notetypesClient) private var notetypesClient

    init(noteIDs: [NoteID]) {
        self.noteIDs = noteIDs
    }

    // The engine expands $1 / ${name} in the replacement even when regex is off.
    private var literalSafeReplacement: String {
        useRegex ? replacement : replacement.replacing("$", with: "$$")
    }

    private struct Inputs: Equatable {
        let find, replacement, fieldName: String
        let useRegex, matchCase: Bool
    }

    private var inputs: Inputs {
        Inputs(find: find, replacement: replacement, fieldName: fieldName, useRegex: useRegex, matchCase: matchCase)
    }

    // Set after a successful run so the same inputs can't be applied twice; cleared by undo.
    private var lastApplied: Inputs?

    var canApply: Bool { !find.isEmpty && !isWorking && lastApplied != inputs }

    func loadFieldNames() async {
        guard !noteIDs.isEmpty else {
            fieldNames = (try? await wholeCollectionFieldNames()) ?? []
            return
        }
        fieldNames = (try? await noteClient.fieldNamesForNotes(noteIDs)) ?? []
    }

    func apply() async {
        guard canApply else { return }
        isWorking = true
        defer { isWorking = false }
        let applied = inputs
        do {
            let count = try await noteClient.findAndReplace(
                noteIDs, find, literalSafeReplacement, useRegex, matchCase, fieldName
            )
            outcome = .updated(count)
            canUndo = count > 0
            lastApplied = applied
        } catch {
            // The engine wraps regex parse errors in <pre> tags.
            let message = error.localizedDescription
                .replacing(/<\/?pre>/, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            outcome = .failed(message)
            canUndo = false
        }
    }

    func undo() async {
        guard canUndo, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await cardClient.undoLast()
            outcome = .undone
            lastApplied = nil
        } catch {
            outcome = .failed(error.localizedDescription)
        }
        canUndo = false
    }

    private func wholeCollectionFieldNames() async throws -> [String] {
        var names: [String] = []
        for entry in try await notetypesClient.listAll() {
            for field in try await notetypesClient.get(entry.id).fields where !names.contains(field.name) {
                names.append(field.name)
            }
        }
        return names.sorted()
    }
}
