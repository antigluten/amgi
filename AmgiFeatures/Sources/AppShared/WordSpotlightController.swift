package import AppCore
import AnkiClients
package import AnkiKit
import Dependencies
package import Foundation
package import Observation
import os
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
    private var publishedPreferences: WordSpotlightPreferences?
    private var savingPreferences = false

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

    /// Drops a profile's Word Spotlight state; for the active profile also clears the widget and reminders.
    package func reset(profileID: String) {
        if profileID == AccountStore.shared.selectedID {
            generation += 1
            profileGeneration += 1
            clear()
        }
        WordSpotlightStore.removeProfile(profileID)
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
        savingPreferences = true
        defer { savingPreferences = false }
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
        publishedPreferences = preferences
    }

    package func requestNotificationPermission() async throws -> Bool {
        try await notifications.requestPermission()
    }

    @discardableResult
    package func refresh(advance: Bool = false) async -> Bool {
        await enqueue { await self.update(advance: advance) }
    }

    /// Foreground and screen-open path: rebuilds only when the published schedule can't serve the next day.
    @discardableResult
    package func refreshIfNeeded() async -> Bool {
        await enqueue {
            let preferences = WordSpotlightStore.preferences(profileID: AccountStore.shared.selectedID)
            if let schedule = self.schedule, self.isFresh(schedule, for: preferences) { return true }
            return await self.update(advance: false)
        }
    }

    private func isFresh(_ schedule: WordSpotlightSchedule, for preferences: WordSpotlightPreferences) -> Bool {
        guard preferences.isConfigured, schedule.profileID == AccountStore.shared.selectedID,
              schedule.source == preferences.sourceID, schedule.intervalHours == preferences.rotationHours,
              schedule.timeZoneID == Calendar.current.timeZone.identifier,
              let expiration = schedule.expiration() else { return false }
        return expiration > Date.now.addingTimeInterval(24 * 3600)
    }

    /// Save and advance must finish before foreground refresh can publish another schedule.
    private func enqueue(_ operation: @escaping @MainActor () async throws -> Bool) async -> Bool {
        let previous = updateTask
        let profileID = AccountStore.shared.selectedID
        let revision = profileGeneration
        let task = Task {
            _ = await previous?.value
            guard !switchingProfile, revision == profileGeneration,
                  profileID == AccountStore.shared.selectedID else { return false }
            do { return try await operation() }
            catch {
                if revision == profileGeneration { self.updateError = error.localizedDescription }
                return false
            }
        }
        updateTask = task
        guard let result = await value(of: task, timeout: Self.operationTimeout) else {
            Log.widget.error("Word Spotlight update timed out")
            if revision == profileGeneration { updateError = WordSpotlightError.timedOut.localizedDescription }
            return false
        }
        return result
    }

    private static let operationTimeout = Duration.seconds(30)

    private func update(advance: Bool) async -> Bool {
        if advance { pendingAdvance += 1 }
        generation += 1
        let revision = generation
        let profileID = AccountStore.shared.selectedID
        updateError = nil
        notifications.error = nil
        let preferences: WordSpotlightPreferences
        do { preferences = try WordSpotlightStore.loadPreferences(profileID: profileID) } catch {
            // Unreadable settings are not "disabled": keep the published widget until the user re-saves.
            pendingAdvance = 0
            updateError = WordSpotlightError.invalidSource.localizedDescription
            return false
        }
        guard preferences.isConfigured else {
            if schedule != nil || WordSpotlightStore.read() != nil { clear() }
            return true
        }
        do {
            let words = try await preview(preferences, profileID: profileID)
            guard isCurrent(revision, profileID: profileID) else { return false }
            let schedule = try prepareSchedule(from: words, preferences: preferences, profileID: profileID)
            try publish(schedule, wordCount: words.count, preferences: preferences)
            updateError = nil
            return true
        } catch {
            guard isCurrent(revision, profileID: profileID) else { return false }
            pendingAdvance = 0
            Log.widget.error("Word Spotlight update failed: \(String(describing: error))")
            // A source that no longer exists must not keep serving its old words for two weeks.
            if !savingPreferences, let error = error as? WordSpotlightError,
               error == .invalidSource || error == .noWords { clear() }
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
        pendingAdvance = 0
        self.wordCount = wordCount
        if schedule != self.schedule || preferences != publishedPreferences {
            try WordSpotlightStore.write(schedule)
            self.schedule = schedule
            publishedPreferences = preferences
            WidgetCenter.shared.reloadTimelines(ofKind: WordSpotlightStore.widgetKind)
        }
        // Always re-sync reminders (idempotent): permission may have been granted since the last publish.
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
        publishedPreferences = nil
        wordCount = 0
        do { try WordSpotlightStore.clear() } catch { self.updateError = error.localizedDescription }
        WidgetCenter.shared.reloadTimelines(ofKind: WordSpotlightStore.widgetKind)
        notifications.update(schedule: nil, preferences: WordSpotlightPreferences())
    }
}

/// FFI calls can't be cancelled; this only stops the UI waiting on a hung one, the queue stays serial.
@MainActor
private func value(of task: Task<Bool, Never>, timeout: Duration) async -> Bool? {
    final class Once { var resumed = false }
    let once = Once()
    return await withCheckedContinuation { continuation in
        let timer = Task { @MainActor in
            try? await Task.sleep(for: timeout)
            guard !once.resumed else { return }
            once.resumed = true
            continuation.resume(returning: nil)
        }
        Task { @MainActor in
            let result = await task.value
            timer.cancel()
            guard !once.resumed else { return }
            once.resumed = true
            continuation.resume(returning: result)
        }
    }
}

enum WordSpotlightError: LocalizedError {
    case invalidSource, missingWord, differentProfile, noWords, timedOut

    var errorDescription: String? {
        switch self {
        case .invalidSource: "Choose an existing vocabulary deck, note type, and word/meaning fields in Settings."
        case .missingWord: "This word is no longer available. It may have been deleted or its fields changed."
        case .differentProfile: "This word belongs to another profile. Switch to that profile to view it."
        case .noWords: "No eligible words found. Check the selected fields and add vocabulary cards to this deck."
        case .timedOut: "Loading your vocabulary took too long. Try again."
        }
    }
}
