import AnkiKit
import AnkiClients
import AnkiServices
import Dependencies
import SwiftUI

/// Data state + load/save logic for the Add Note form. Mirrors the other
/// screen models: the View owns navigation, the toolbar, and dismissal,
/// while the model owns deck/notetype loading, field assembly, and the note
/// write so the form stays testable and the View stays thin.
@Observable
@MainActor
final class AddNoteModel {
    var decks: [DeckInfo] = []
    var notetypeNames: [(id: NotetypeID, name: String)] = []
    var selectedDeckId: DeckID = DeckID(1)
    var selectedNotetypeId: NotetypeID = NotetypeID(0)
    var fieldNames: [String] = []
    var fieldValues: [String] = []
    var tags: String = ""
    var isSaving = false
    var errorMessage: String?

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient
    @ObservationIgnored @Dependency(\.notetypesService) private var notetypesService
    @ObservationIgnored @Dependency(\.notesService) private var notesService
    @ObservationIgnored @Dependency(\.collectionStore) private var store

    @ObservationIgnored private let preselectedDeckId: DeckID?
    @ObservationIgnored private let initialDraft: AddNoteDraft?

    init(preselectedDeckId: DeckID? = nil, initialDraft: AddNoteDraft? = nil) {
        self.preselectedDeckId = preselectedDeckId
        self.initialDraft = initialDraft
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

    func loadData() async {
        decks = (try? await deckClient.fetchAll()) ?? []
        if let preselectedDeckId, decks.contains(where: { $0.id == preselectedDeckId }) {
            selectedDeckId = preselectedDeckId
        } else if let first = decks.first {
            selectedDeckId = first.id
        }

        do {
            notetypeNames = try notetypesService.getNotetypeNames()
            // Honour an incoming draft's preferred notetype when it matches
            // one the user actually has; otherwise fall back to the first.
            let chosen = initialDraft?.notetypeID
                .flatMap { id in notetypeNames.first(where: { $0.id.rawValue == id }) }
                ?? notetypeNames.first
            if let chosen {
                selectedNotetypeId = chosen.id
                loadFields()
            }
        } catch {
            print("[AddNote] Error loading notetypes: \(error)")
        }

        if let initialDraft, !initialDraft.tags.isEmpty {
            tags = initialDraft.tags.joined(separator: " ")
        }
    }

    func loadFields() {
        guard selectedNotetypeId.rawValue != 0 else { return }
        do {
            let notetype = try notetypesService.getNotetype(selectedNotetypeId)
            fieldNames = notetype.fieldNames
            // Pre-fill from the incoming draft by mapping
            // `fieldValues[name] → fieldValues[positionalIndex]` against the
            // notetype's actual field-name list. Names not present on this
            // notetype are silently dropped.
            fieldValues = fieldNames.map { name in
                initialDraft?.fieldValues[name] ?? ""
            }
        } catch {
            print("[AddNote] Error loading fields: \(error)")
        }
    }

    /// Persist the note. Returns whether the write succeeded; on failure
    /// `errorMessage` carries the reason. Navigation/dismissal stays with
    /// the View.
    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            var template = try notesService.newNote(selectedNotetypeId)
            template.fields = fieldValues
            template.tags = tags.split(separator: " ").map(String.init)
            try notesService.addNote(template, selectedDeckId)
            // addNote doesn't surface OpChanges yet — invalidate the shared
            // tree cache conservatively so every host (DeckDetail, reader
            // lookup, Browse) sees fresh counts.
            store.apply(CollectionChanges(card: true, note: true, studyQueues: true))
            return true
        } catch {
            errorMessage = "Failed to add note: \(error.localizedDescription)"
            return false
        }
    }
}
