package import AppCore
import AnkiClients
package import AnkiKit
import Dependencies
package import Foundation
package import Observation
import WidgetKit

@MainActor
@Observable
package final class WordSpotlightController {
    package static let shared = WordSpotlightController()
    package var pendingLink: WordSpotlightLink? {
        get { notifications.pendingLink }
        set { notifications.pendingLink = newValue }
    }
    package var error: String? { updateError ?? notifications.error }
    private var updateError: String?
    package private(set) var schedule: WordSpotlightSchedule?
    package private(set) var wordCount = 0
    package var currentWord: SpotlightWord? { schedule?.word(on: .now) }
    package var canAdvance: Bool { wordCount > 1 }
    package var notificationsDenied: Bool { notifications.notificationsDenied }
    private let notifications = WordSpotlightNotifications()

    private var generation = 0
    private var profileGeneration = 0
    private var switchingProfile = false
    private var pendingAdvance = 0
    private var updateTask: Task<Bool, Never>?

    package func installNotificationDelegate() {
        notifications.installDelegate()
    }

    package func beginProfileSwitch() {
        switchingProfile = true
        pendingAdvance = 0
        generation += 1
        profileGeneration += 1
        pendingLink = nil
        clear()
    }

    package func finishProfileSwitch() {
        switchingProfile = false
        Task { await refresh() }
    }

    @discardableResult
    package func save(_ preferences: WordSpotlightPreferences, profileID: String) async -> Bool {
        guard profileID == AccountStore.shared.selectedID, !switchingProfile else { return false }
        return await enqueue { try await self.savePreferences(preferences, profileID: profileID) }
    }

    private func savePreferences(_ preferences: WordSpotlightPreferences, profileID: String) async throws -> Bool {
        let original = WordSpotlightStore.preferences(profileID: profileID)
        try WordSpotlightStore.save(preferences, profileID: profileID)
        if onlyRemindersChanged(from: original, to: preferences) {
            updateError = nil
            refreshReminders(preferences, profileID: profileID)
            return true
        }
        let success = await update(advance: false)
        if !success, profileID == AccountStore.shared.selectedID,
           WordSpotlightStore.preferences(profileID: profileID) == preferences {
            try WordSpotlightStore.save(original, profileID: profileID)
        }
        return success
    }

    private func onlyRemindersChanged(from original: WordSpotlightPreferences, to updated: WordSpotlightPreferences) -> Bool {
        original.isConfigured && updated != original
            && updated.sourceID == original.sourceID
            && updated.rotationHours == original.rotationHours
    }

    private func refreshReminders(_ preferences: WordSpotlightPreferences, profileID: String) {
        // Reminder privacy must remain editable when the vocabulary source cannot load.
        let cached = schedule ?? WordSpotlightStore.read()
        let matchingSchedule = cached.flatMap {
            $0.profileID == profileID && $0.source == preferences.sourceID ? $0 : nil
        }
        notifications.update(schedule: matchingSchedule, preferences: preferences)
    }

    package func requestNotificationPermission() async throws -> Bool {
        try await notifications.requestPermission()
    }

    @discardableResult
    package func refresh(advance: Bool = false) async -> Bool {
        // Bootstrap refreshes stay off during tests; independent controllers use injected clients.
        if self === Self.shared,
           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return false }
        return await enqueue { await self.update(advance: advance) }
    }

    /// Save and advance must finish before foreground refresh can publish another schedule.
    private func enqueue(_ operation: @escaping @MainActor () async throws -> Bool) async -> Bool {
        let previous = updateTask
        let profileID = AccountStore.shared.selectedID
        let revision = profileGeneration
        let task = Task {
            await previous?.value
            guard !switchingProfile, revision == profileGeneration,
                  profileID == AccountStore.shared.selectedID else { return false }
            do { return try await operation() }
            catch {
                if revision == profileGeneration { self.updateError = error.localizedDescription }
                return false
            }
        }
        updateTask = task
        return await task.value
    }

    private func update(advance: Bool) async -> Bool {
        if advance { pendingAdvance += 1 }
        generation += 1
        let revision = generation
        let profileID = AccountStore.shared.selectedID
        let preferences = WordSpotlightStore.preferences(profileID: profileID)
        updateError = nil
        notifications.error = nil
        guard preferences.isConfigured else {
            clear()
            return true
        }
        do {
            let words = try await preview(preferences, profileID: profileID)
            guard isCurrent(revision, profileID: profileID) else { return false }
            let schedule = try prepareSchedule(from: words, preferences: preferences, profileID: profileID)
            try publish(schedule, wordCount: words.count, preferences: preferences)
            return true
        } catch {
            guard isCurrent(revision, profileID: profileID) else { return false }
            pendingAdvance = 0
            self.updateError = error.localizedDescription
            return false
        }
    }

    private func prepareSchedule(
        from words: [SpotlightWord], preferences: WordSpotlightPreferences, profileID: String
    ) throws -> WordSpotlightSchedule {
        guard !words.isEmpty else { throw WordSpotlightError.noWords }
        return WordSpotlightSchedule.make(
            profileID: profileID, source: preferences.sourceID, words: words,
            previous: WordSpotlightStore.rotation(profileID: profileID),
            intervalHours: preferences.rotationHours, advanceBy: pendingAdvance
        )
    }

    private func publish(_ schedule: WordSpotlightSchedule, wordCount: Int, preferences: WordSpotlightPreferences) throws {
        try WordSpotlightStore.write(schedule)
        pendingAdvance = 0
        self.schedule = schedule
        self.wordCount = wordCount
        WidgetCenter.shared.reloadTimelines(ofKind: WordSpotlightStore.widgetKind)
        notifications.update(schedule: schedule, preferences: preferences)
    }

    /// Reads a draft source without changing the active widget or its reminders.
    package func preview(_ preferences: WordSpotlightPreferences, profileID: String) async throws -> [SpotlightWord] {
        let revision = profileGeneration
        func checkProfile() throws {
            try Task.checkCancellation()
            guard !switchingProfile, revision == profileGeneration,
                  profileID == AccountStore.shared.selectedID else { throw WordSpotlightError.differentProfile }
        }
        try checkProfile()
        guard preferences.isConfigured else { throw WordSpotlightError.invalidSource }
        return try await WordSpotlightSource.load(preferences, validate: checkProfile)
    }

    package func loadWord(_ link: WordSpotlightLink) async throws -> SpotlightWord {
        guard link.profileID == AccountStore.shared.selectedID, !switchingProfile else {
            throw WordSpotlightError.differentProfile
        }
        let revision = profileGeneration
        @Dependency(\.noteClient) var noteClient
        @Dependency(\.notetypesClient) var notetypesClient
        guard let note = try await noteClient.fetch(NoteID(link.noteID)) else {
            throw WordSpotlightError.missingWord
        }
        guard revision == profileGeneration, link.profileID == AccountStore.shared.selectedID,
              !switchingProfile else { throw WordSpotlightError.differentProfile }
        let preferences = WordSpotlightStore.preferences(profileID: link.profileID)
        guard note.mid.rawValue == preferences.notetypeID else { throw WordSpotlightError.invalidSource }
        let notetype = try await notetypesClient.get(note.mid)
        guard revision == profileGeneration, link.profileID == AccountStore.shared.selectedID,
              !switchingProfile else { throw WordSpotlightError.differentProfile }
        guard let word = WordSpotlightSource.word(from: note, fields: notetype.fields.map(\.name), preferences: preferences)
        else { throw WordSpotlightError.missingWord }
        return word
    }

    private func isCurrent(_ revision: Int, profileID: String) -> Bool {
        generation == revision && AccountStore.shared.selectedID == profileID && !switchingProfile
    }

    private func clear() {
        pendingAdvance = 0
        schedule = nil
        wordCount = 0
        do { try WordSpotlightStore.clear() } catch { self.updateError = error.localizedDescription }
        WidgetCenter.shared.reloadTimelines(ofKind: WordSpotlightStore.widgetKind)
        notifications.update(schedule: nil, preferences: WordSpotlightPreferences())
    }
}

enum WordSpotlightError: LocalizedError {
    case invalidSource, missingWord, differentProfile, noWords

    var errorDescription: String? {
        switch self {
        case .invalidSource: "Choose an existing vocabulary deck, note type, and word/meaning fields in Settings."
        case .missingWord: "This word is no longer available. It may have been deleted or its fields changed."
        case .differentProfile: "This word belongs to another profile. Switch to that profile to view it."
        case .noWords: "No eligible words found. Check the selected fields and add vocabulary cards to this deck."
        }
    }
}
