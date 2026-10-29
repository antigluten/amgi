//
//  AddNoteModel.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 22.06.2026.
//

import Foundation
import OSLog
import AppCore
import AppShared
import AnkiBackend
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
    var fieldAudio: [[URL]] = []
    var isSaving = false
    var isLoadingFields = false
    var errorMessage: String?

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient
    @ObservationIgnored @Dependency(\.notetypesService) private var notetypesService
    @ObservationIgnored @Dependency(\.notesService) private var notesService
    @ObservationIgnored @Dependency(\.collectionStore) private var store

    @ObservationIgnored @Dependency(\.mediaClient) private var mediaClient

    @ObservationIgnored private let preselectedDeckId: DeckID?
    @ObservationIgnored private let initialDraft: AddNoteDraft?

    @ObservationIgnored private var baselineFieldValues: [String] = []
    @ObservationIgnored private var baselineTags: String = ""
    @ObservationIgnored private var fieldLoadRequest: UUID?

    var hasUnsavedChanges: Bool {
        fieldValues != baselineFieldValues || tags != baselineTags || hasAudio
    }

    var hasAudio: Bool { fieldAudio.contains { !$0.isEmpty } }

    var canAdd: Bool {
        !isSaving && !isLoadingFields && (!fieldValues.allSatisfy(\.isEmpty) || hasAudio)
    }

    func attachAudio(_ url: URL, toField index: Int) {
        guard !isSaving, fieldAudio.indices.contains(index) else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        fieldAudio[index].append(url)
    }

    func removeAudio(_ url: URL, fromField index: Int) {
        guard !isSaving, fieldAudio.indices.contains(index) else { return }
        fieldAudio[index].removeAll { $0 == url }
        try? FileManager.default.removeItem(at: url)
    }

    func discardAudio() {
        for url in fieldAudio.flatMap({ $0 }) {
            try? FileManager.default.removeItem(at: url)
        }
        fieldAudio = fieldAudio.map { _ in [] }
    }

    /// Keep recordings only when their named field exists in the new note type.
    func reconcileAudio(with names: [String]) {
        let previous = fieldAudio
        fieldAudio = names.map { name in
            guard let index = fieldNames.firstIndex(of: name), previous.indices.contains(index) else {
                return []
            }
            return previous[index]
        }
        let kept = Set(fieldAudio.flatMap { $0 })
        for url in previous.flatMap({ $0 }) where !kept.contains(url) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Stable recording filenames make a failed note save safe to retry without
    /// uploading a second copy of every clip. Temporary originals stay until success.
    func fieldsWithAudio() async throws -> [String] {
        var fields = fieldValues
        for (index, clips) in fieldAudio.enumerated() where fields.indices.contains(index) {
            for url in clips {
                try await mediaClient.save(Data(contentsOf: url), url.lastPathComponent)
                let marker = "[sound:\(url.lastPathComponent)]"
                fields[index] += fields[index].isEmpty ? marker : " " + marker
            }
        }
        return fields
    }

    init(preselectedDeckId: DeckID? = nil, initialDraft: AddNoteDraft? = nil) {
        self.preselectedDeckId = preselectedDeckId
        self.initialDraft = initialDraft
    }

    /// Positional projection into `fieldValues`, read through `@Bindable` as
    /// `$model[fieldAt: index]`. A subscript rather than a
    /// `Binding(get:set:)`-returning method so the field editors get a stable
    /// binding instead of a freshly-allocated closure pair on every body pass.
    subscript(fieldAt index: Int) -> String {
        get { index < fieldValues.count ? fieldValues[index] : "" }
        set { if index < fieldValues.count { fieldValues[index] = newValue } }
    }

    func loadData() async {
        decks = (try? await deckClient.fetchAll()) ?? []
        if let preselectedDeckId, decks.contains(where: { $0.id == preselectedDeckId }) {
            selectedDeckId = preselectedDeckId
        } else if let first = decks.first {
            selectedDeckId = first.id
        }

        do {
            let service = notetypesService
            notetypeNames = try await backendOffload { try service.getNotetypeNames() }
            // Honour an incoming draft's preferred notetype when it matches
            // one the user actually has; otherwise fall back to the first.
            let chosen = initialDraft?.notetypeID
                .flatMap { id in notetypeNames.first(where: { $0.id.rawValue == id }) }
                ?? notetypeNames.first
            if let chosen {
                selectedNotetypeId = chosen.id
                await loadFields()
            }
        } catch {
            Log.browse.error("Error loading notetypes: \(error)")
        }

        if let initialDraft, !initialDraft.tags.isEmpty {
            tags = initialDraft.tags.joined(separator: " ")
        }
        baselineTags = tags
    }

    func loadFields() async {
        guard selectedNotetypeId.rawValue != 0 else { return }
        let request = UUID()
        fieldLoadRequest = request
        isLoadingFields = true
        defer {
            if fieldLoadRequest == request { isLoadingFields = false }
        }
        do {
            let service = notetypesService
            let id = selectedNotetypeId
            let notetype = try await backendOffload { try service.getNotetype(id) }
            // A previous async load must not re-map recordings onto stale fields.
            guard fieldLoadRequest == request, selectedNotetypeId == id else { return }
            reconcileAudio(with: notetype.fieldNames)
            fieldNames = notetype.fieldNames
            // Pre-fill from the incoming draft by mapping
            // `fieldValues[name] → fieldValues[positionalIndex]` against the
            // notetype's actual field-name list. Names not present on this
            // notetype are silently dropped.
            fieldValues = fieldNames.map { name in
                initialDraft?.fieldValues[name] ?? ""
            }
            baselineFieldValues = fieldValues
        } catch {
            Log.browse.error("Error loading fields: \(error)")
        }
    }

    /// Persist the note. Returns whether the write succeeded; on failure
    /// `errorMessage` carries the reason. Navigation/dismissal stays with
    /// the View.
    func save() async -> Bool {
        guard canAdd else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let notes = notesService
            let notetypeID = selectedNotetypeId
            let deckID = selectedDeckId
            let fields = try await fieldsWithAudio()
            let tagList = tags.split(separator: " ").map(String.init)
            try await backendOffload {
                var template = try notes.newNote(notetypeID)
                template.fields = fields
                template.tags = tagList
                try notes.addNote(template, deckID)
            }
            // addNote doesn't surface OpChanges yet — invalidate the shared
            // tree cache conservatively so every host (DeckDetail, reader
            // lookup, Browse) sees fresh counts.
            store.apply(CollectionChanges(card: true, note: true, studyQueues: true))
            discardAudio()
            return true
        } catch {
            errorMessage = "Failed to add note: \(error.localizedDescription)"
            return false
        }
    }
}
