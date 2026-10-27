package import Foundation

package enum WordSpotlightStore {
    // Keep persisted identifiers stable for existing settings, links, and installed widgets.
    package static let widgetKind = "WordOfDayWidget"

    /// Private to the app: clearing a widget on profile switch must not reset that profile's rotation.
    package static func rotation(profileID: String) -> WordSpotlightSchedule? {
        guard let data = UserDefaults.standard.data(forKey: "wordOfDay.rotation.\(profileID)") else { return nil }
        return try? JSONDecoder().decode(WordSpotlightSchedule.self, from: data)
    }

    package static func preferences(profileID: String) -> WordSpotlightPreferences {
        guard let data = UserDefaults.standard.data(forKey: "wordOfDay.\(profileID)"),
              let preferences = try? JSONDecoder().decode(WordSpotlightPreferences.self, from: data)
        else { return WordSpotlightPreferences() }
        return preferences
    }

    package static func save(_ preferences: WordSpotlightPreferences, profileID: String) throws {
        UserDefaults.standard.set(try JSONEncoder().encode(preferences), forKey: "wordOfDay.\(profileID)")
    }

    package static func read() -> WordSpotlightSchedule? {
        guard let url = try? fileURL(), let data = try? Data(contentsOf: url) else { return nil }
        guard let schedule = try? JSONDecoder().decode(WordSpotlightSchedule.self, from: data),
              UserDefaults(suiteName: AppGroup.identifier)?.string(forKey: "wordOfDay.activeProfile") == schedule.profileID
        else { return nil }
        return schedule
    }

    package static func write(_ schedule: WordSpotlightSchedule) throws {
        try JSONEncoder().encode(schedule).write(to: fileURL(), options: .atomic)
        UserDefaults(suiteName: AppGroup.identifier)?.set(schedule.profileID, forKey: "wordOfDay.activeProfile")
        // One slot's anchor suffices to resume this profile's rotation.
        let anchor = WordSpotlightSchedule(profileID: schedule.profileID, source: schedule.source,
                                      entries: Array(schedule.entries.prefix(1)), intervalHours: schedule.intervalHours)
        UserDefaults.standard.set(try JSONEncoder().encode(anchor), forKey: "wordOfDay.rotation.\(schedule.profileID)")
    }

    package static func clear() throws {
        // Fail closed for readers even if deleting a protected file fails.
        UserDefaults(suiteName: AppGroup.identifier)?.removeObject(forKey: "wordOfDay.activeProfile")
        let url = try fileURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static func fileURL() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else { throw CocoaError(.fileNoSuchFile) }
        return container.appendingPathComponent("word-of-day.json")
    }
}
