import AppCore
import AppShared
import AnkiClients
import AnkiKit
import Dependencies
import Foundation
import Observation

@MainActor
@Observable
final class WordSpotlightSettingsModel {
    var preferences = WordSpotlightPreferences()
    var savedPreferences = WordSpotlightPreferences()
    var profileID = ""
    var decks: [DeckInfo] = []
    var notetypes: [NotetypeNameId] = []
    var fields: [String] = []
    enum PreviewState {
        case idle
        case loading
        case ready(source: String, words: [SpotlightWord])
        case failed(String)
    }

    private(set) var preview = PreviewState.idle
    private enum Activity {
        case idle, loading, saving, advancing
    }

    private var activity = Activity.loading
    var isSaving: Bool { activity == .saving }
    var isAdvancing: Bool { activity == .advancing }
    var isLoading: Bool { activity == .loading }
    private enum RetryAction {
        case load, fields, refresh, source, advance, disable
        case options(WordSpotlightPreferences)
    }

    private struct Failure {
        var message: String
        var retry: RetryAction
    }

    private var failure: Failure?
    var error: String? { failure?.message }
    var sourceStatus: String?
    let controller: WordSpotlightController

    init(controller: WordSpotlightController = .shared) {
        self.controller = controller
    }

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient
    @ObservationIgnored @Dependency(\.notetypesClient) private var notetypesClient

    var needsSourceSave: Bool {
        !savedPreferences.isConfigured || preferences.sourceID != savedPreferences.sourceID
    }

    var canSaveSource: Bool {
        guard needsSourceSave, preferences.isConfigured,
              case .ready(let source, let words) = preview else { return false }
        return source == preferences.sourceID && !words.isEmpty
    }

    func retry() async {
        let action = failure?.retry ?? .refresh
        failure = nil
        switch action {
        case .load: await load()
        case .fields: await loadFields()
        case .refresh: await controller.refresh()
        case .source: await saveSource()
        case .options(let options):
            applyOptions(options)
            await saveOptions()
        case .advance: await advance()
        case .disable: await disable()
        }
    }

    func disable() async {
        failure = nil
        activity = .saving
        defer { activity = .idle }
        let disabled = WordSpotlightPreferences()
        if await controller.save(disabled, profileID: profileID) {
            savedPreferences = disabled
            preferences = disabled
            sourceStatus = nil
        } else if let message = controller.error {
            failure = Failure(message: message, retry: .disable)
        }
    }

    func optionValues(_ value: WordSpotlightPreferences) -> [Int] {
        [value.rotationHours, value.hour, value.minute, value.notifications ? 1 : 0, value.showWord ? 1 : 0]
    }

    func load() async {
        activity = .loading
        failure = nil
        defer { activity = .idle }
        restoreProfilePreferencesIfNeeded()
        do {
            let decks = try await deckClient.fetchAll().filter { !$0.isFiltered }.sortedByName
            let notetypes = try await notetypesClient.listAll()
            guard !Task.isCancelled, profileID == AccountStore.shared.selectedID else { return }
            self.decks = decks
            self.notetypes = notetypes
            selectInitialSourceIfNeeded()
            await loadFields()
            guard failure == nil else { return }
            await controller.refresh()
        } catch { failure = Failure(message: error.localizedDescription, retry: .load) }
    }

    private func restoreProfilePreferencesIfNeeded() {
        guard profileID != AccountStore.shared.selectedID else { return }
        profileID = AccountStore.shared.selectedID
        preferences = WordSpotlightStore.preferences(profileID: profileID)
        savedPreferences = preferences
    }

    private func selectInitialSourceIfNeeded() {
        guard !preferences.isConfigured else { return }
        let template = ReaderLookupNoteTemplate.decode(
            from: UserDefaults.standard.string(forKey: "reader_pref_lookup_note_template") ?? ""
        )
        if let deckID = template.deckID, let notetypeID = template.notetypeID,
           decks.contains(where: { $0.id.rawValue == deckID }),
           notetypes.contains(where: { $0.id.rawValue == notetypeID }) {
            preferences.deckID = deckID
            preferences.notetypeID = notetypeID
            preferences.termField = template.termField
            preferences.readingField = template.readingField
            preferences.meaningField = template.definition1Field
        } else {
            if decks.count == 1 { preferences.deckID = decks[0].id.rawValue }
            if notetypes.count == 1 { preferences.notetypeID = notetypes[0].id.rawValue }
        }
    }

    func loadFields() async {
        if case .some(.fields) = failure?.retry { failure = nil }
        let id = preferences.notetypeID
        guard id > 0 else { fields = []; return }
        do {
            let notetype = try await notetypesClient.get(NotetypeID(id))
            guard !Task.isCancelled, profileID == AccountStore.shared.selectedID, preferences.notetypeID == id else { return }
            fields = notetype.fields.map(\.name)
            applySuggestedFields(for: id)
        } catch {
            guard !Task.isCancelled, profileID == AccountStore.shared.selectedID, preferences.notetypeID == id else { return }
            fields = []
            failure = Failure(message: error.localizedDescription, retry: .fields)
        }
    }

    private func applySuggestedFields(for notetypeID: Int64) {
        if !fields.contains(preferences.termField) {
            preferences.termField = suggestedField(named: ["expression", "term", "word", "front"])
        }
        if !fields.contains(preferences.meaningField) {
            preferences.meaningField = suggestedField(named: ["meaning", "definition", "translation", "back"])
        }
        if !fields.contains(preferences.readingField) { preferences.readingField = "" }
        if preferences.readingField.isEmpty,
           !savedPreferences.isConfigured || notetypeID != savedPreferences.notetypeID {
            preferences.readingField = suggestedField(named: ["reading", "pronunciation"])
        }
    }

    private func suggestedField(named candidates: [String]) -> String {
        candidates.compactMap { name in fields.first { $0.lowercased() == name } }.first ?? ""
    }

    func loadPreview() async {
        preview = .idle
        guard !isLoading, needsSourceSave, preferences.isConfigured else { return }
        let draft = preferences
        preview = .loading
        do {
            let words = try await controller.preview(draft, profileID: profileID)
            guard !Task.isCancelled, draft.sourceID == preferences.sourceID else { return }
            preview = .ready(source: draft.sourceID, words: words)
        } catch {
            guard !Task.isCancelled, draft.sourceID == preferences.sourceID else { return }
            preview = .failed(error.localizedDescription)
        }
    }

    func saveSource() async {
        activity = .saving
        failure = nil
        defer { activity = .idle }
        do {
            if preferences.notifications {
                preferences.notifications = try await controller.requestNotificationPermission()
            }
            if await controller.save(preferences, profileID: profileID) {
                savedPreferences = preferences
                sourceStatus = "Source saved"
            } else if let message = controller.error {
                failure = Failure(message: message, retry: .source)
            }
        } catch { failure = Failure(message: error.localizedDescription, retry: .source) }
    }

    func saveOptions() async {
        guard !isSaving else { return }
        activity = .saving
        failure = nil
        defer { activity = .idle }
        var updated = optionsForSavedSource
        do {
            if updated.notifications && !savedPreferences.notifications {
                updated.notifications = try await controller.requestNotificationPermission()
                preferences.notifications = updated.notifications
            }
            if await controller.save(updated, profileID: profileID) {
                savedPreferences = updated
            } else {
                restoreOptions()
                if let message = controller.error {
                    failure = Failure(message: message, retry: .options(updated))
                }
            }
        } catch {
            restoreOptions()
            failure = Failure(message: error.localizedDescription, retry: .options(updated))
        }
    }

    private var optionsForSavedSource: WordSpotlightPreferences {
        // Apply controls to the saved source, never to unconfirmed field edits.
        var updated = savedPreferences
        updated.intervalHours = preferences.intervalHours
        updated.hour = preferences.hour
        updated.minute = preferences.minute
        updated.showWord = preferences.showWord
        updated.notifications = preferences.notifications
        return updated
    }

    private func restoreOptions() {
        applyOptions(savedPreferences)
    }

    private func applyOptions(_ options: WordSpotlightPreferences) {
        preferences.intervalHours = options.intervalHours
        preferences.hour = options.hour
        preferences.minute = options.minute
        preferences.notifications = options.notifications
        preferences.showWord = options.showWord
    }

    func advance() async {
        activity = .advancing
        failure = nil
        if !(await controller.refresh(advance: true)), let message = controller.error {
            failure = Failure(message: message, retry: .advance)
        }
        activity = .idle
    }
}
