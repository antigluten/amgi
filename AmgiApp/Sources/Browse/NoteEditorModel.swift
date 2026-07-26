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

    /// Positional binding into `fieldValues` for the field at `index`.
    func fieldBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < self.fieldValues.count ? self.fieldValues[index] : "" },
            set: { newValue in
                if index < self.fieldValues.count { self.fieldValues[index] = newValue }
            }
        )
    }

    func loadNote() {
        do {
            let notetype = try notetypesService.getNotetype(note.mid)
            fieldNames = notetype.fieldNames
        } catch {
            print("[NoteEditorModel] Error loading notetype: \(error)")
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
            try noteClient.save(updatedNote)
            return true
        } catch {
            return false
        }
    }
}
