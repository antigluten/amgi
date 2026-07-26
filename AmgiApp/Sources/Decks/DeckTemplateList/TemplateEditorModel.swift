import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Notetype loading/saving for the template editor. Owns the notetypes +
/// note clients, the editable `Notetype`, the selected template index, and
/// the load/save state so the view carries no `@Dependency`. The editor tab,
/// search text, sheet/dialog flags, and code-editor font prefs stay on the
/// view, whose source bindings write back into `model.notetype`.
@Observable
@MainActor
final class TemplateEditorModel {
    var notetype: Notetype = .init()
    var selectedTemplateIndex = 0
    var isLoading = true
    var isSaving = false
    var errorMessage: String?
    var originalNotetype: Notetype?

    @ObservationIgnored @Dependency(\.notetypesClient) private var notetypesClient
    @ObservationIgnored @Dependency(\.noteClient) private var noteClient

    var hasUnsavedChanges: Bool {
        guard let originalNotetype else { return false }
        return originalNotetype != notetype
    }

    func loadNotetype(notetypeId: NotetypeID, preferred: Int? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            notetype = try notetypesClient.get(notetypeId)
            originalNotetype = notetype
            normalizeTemplateIndex(preferred: preferred)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Persists the edited notetype. Returns `true` on success (after running
    /// `onSaved`) so the view can dismiss; sets `errorMessage` and returns
    /// `false` otherwise so the view can raise the save-error alert.
    func saveTemplate(onSaved: (@Sendable () async -> Void)?) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            try notetypesClient.update(notetype)
            if let onSaved {
                await onSaved()
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func loadSampleFields(notetypeId: NotetypeID, previewNoteId: NoteID?) async throws -> [String] {
        let noteClient = self.noteClient
        let fieldCount = notetype.fields.count
        return try await Task.detached(priority: .userInitiated) {
            if let previewNoteId,
               let currentNote = try noteClient.fetch(previewNoteId) {
                return buildSampleFields(from: currentNote)
            }
            if let sampleNote = try noteClient.search("mid:\(notetypeId.rawValue)", 1).first {
                return buildSampleFields(from: sampleNote)
            }
            return makeEmptySampleFields(fieldCount: fieldCount)
        }.value
    }

    private func normalizeTemplateIndex(preferred: Int? = nil) {
        guard !notetype.templates.isEmpty else {
            selectedTemplateIndex = 0
            return
        }
        if let preferred, notetype.templates.indices.contains(preferred) {
            selectedTemplateIndex = preferred
            return
        }
        if !notetype.templates.indices.contains(selectedTemplateIndex) {
            selectedTemplateIndex = 0
        }
    }
}
