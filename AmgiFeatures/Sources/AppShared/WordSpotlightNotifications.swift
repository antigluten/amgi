import AppCore
import Dependencies
import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class WordSpotlightNotifications: NSObject, UNUserNotificationCenterDelegate {
    var pendingLink: WordSpotlightLink?
    var error: String?
    private(set) var notificationsDenied = false
    private var generation = 0
    private var notificationTask: Task<Void, Never>?
    private static let notificationIDs = (0..<14).map { "word-of-day.\($0)" }
    @ObservationIgnored @Dependency(\.wordSpotlightNotificationClient) private var client

    func installDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async throws -> Bool {
        let granted = try await client.requestPermission()
        notificationsDenied = !granted
        return granted
    }

    /// Serialize remove/add operations so a profile switch cannot leave an in-flight old alert behind.
    @discardableResult
    func update(schedule: WordSpotlightSchedule?, preferences: WordSpotlightPreferences) -> Task<Void, Never> {
        generation += 1
        error = nil
        let previous = notificationTask
        let revision = generation
        let task = Task {
            await previous?.value
            await replaceNotifications(schedule: schedule, preferences: preferences, revision: revision)
        }
        notificationTask = task
        return task
    }

    private func replaceNotifications(
        schedule: WordSpotlightSchedule?, preferences: WordSpotlightPreferences, revision: Int
    ) async {
        guard revision == generation else { return }
        client.removeRequests(Self.notificationIDs)
        let status = await client.authorizationStatus()
        guard revision == generation else { return }
        notificationsDenied = status == .denied
        guard preferences.notifications, let schedule,
              status == .authorized || status == .provisional else { return }
        do {
            try await scheduleNotifications(schedule: schedule, preferences: preferences, revision: revision)
        } catch {
            if revision == generation { self.error = error.localizedDescription }
        }
    }

    private func scheduleNotifications(
        schedule: WordSpotlightSchedule, preferences: WordSpotlightPreferences, revision: Int
    ) async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        for index in 0..<14 {
            guard revision == generation else { return }
            guard let request = notificationRequest(index: index, startingAt: today, calendar: calendar,
                                                     schedule: schedule, preferences: preferences)
            else { continue }
            try await client.addRequest(request)
        }
    }

    private func notificationRequest(
        index: Int, startingAt today: Date, calendar: Calendar,
        schedule: WordSpotlightSchedule, preferences: WordSpotlightPreferences
    ) -> UNNotificationRequest? {
        guard let day = calendar.date(byAdding: .day, value: index, to: today),
              let date = calendar.date(bySettingHour: preferences.hour, minute: preferences.minute,
                                       second: 0, of: day, matchingPolicy: .nextTime, repeatedTimePolicy: .first),
              date > .now, let word = schedule.word(on: date) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.timeZone = calendar.timeZone
        return UNNotificationRequest(
            identifier: Self.notificationIDs[index],
            content: notificationContent(for: word, profileID: schedule.profileID, showWord: preferences.showWord),
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    private func notificationContent(for word: SpotlightWord, profileID: String, showWord: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Word Spotlight"
        content.body = showWord
            ? "\(word.term.prefix(80)) — \(word.meaning.prefix(160))"
            : "Take a moment for vocabulary."
        content.userInfo = ["wordURL": WordSpotlightLink(profileID: profileID, noteID: word.noteID).url?.absoluteString ?? ""]
        return content
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let link = (response.notification.request.content.userInfo["wordURL"] as? String)
            .flatMap(URL.init(string:)).flatMap(WordSpotlightLink.init(url:))
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier, let link {
            Task { @MainActor in self.pendingLink = link }
        }
        completionHandler()
    }
}
