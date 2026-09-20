//
//  NoteEditorModel.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 22.06.2026.
//

import OSLog
import AppCore
import AnkiBackend
import AnkiKit
import AnkiClients
import AnkiServices
import Dependencies
import SwiftUI

/// Field/tag state + load/save logic for editing an existing note. The View
/// owns the toolbar and the "Saved" toast; the model owns notetype lookup,
/// field unpacking, and the note write so the form stays testable.
@Observable
@MainActor
final class NoteEditorModel {
    var fieldNames: [String] = []
    var fieldValues: [String] = []
    var tags: String = ""
    var isSaving = false

    @ObservationIgnored @Dependency(\.noteClient) private var noteClient
    @ObservationIgnored @Dependency(\.notetypesService) private var notetypesService
    @ObservationIgnored private let note: NoteRecord

    init(note: NoteRecord) {
        self.note = note
    }

    /// Positional projection into `fieldValues`, read through `@Bindable` as
    /// `$model[fieldAt: index]`. A subscript rather than a
    /// `Binding(get:set:)`-returning method so the field editors get a stable
    /// binding instead of a freshly-allocated closure pair on every body pass.
    subscript(fieldAt index: Int) -> String {
        get { index < fieldValues.count ? fieldValues[index] : "" }
        set { if index < fieldValues.count { fieldValues[index] = newValue } }
    }

    func loadNote() async {
        do {
            let service = notetypesService
            let mid = note.mid
            let notetype = try await backendOffload { try service.getNotetype(mid) }
            fieldNames = notetype.fieldNames
        } catch {
            Log.browse.error("Error loading notetype: \(error)")
        }

        fieldValues = note.flds
            .split(separator: "\u{1f}", omittingEmptySubsequences: false)
            .map(String.init)
        while fieldValues.count < fieldNames.count { fieldValues.append("") }
        tags = note.tags.trimmingCharacters(in: .whitespaces)
    }

    /// Persist the edited fields/tags. Returns whether the write succeeded.
    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }

        let newFlds = fieldValues.joined(separator: "\u{1f}")
        let newSfld = fieldValues.first ?? ""
        let newCsum = Int64(newSfld.hashValue & 0xFFFFFFFF)

        var updatedNote = note
        updatedNote.flds = newFlds
        updatedNote.sfld = newSfld
        updatedNote.csum = newCsum
        updatedNote.tags = " \(tags) "

        do {
            try await noteClient.save(updatedNote)
            return true
        } catch {
            return false
        }
    }
}
