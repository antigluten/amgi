import AppCore
import Dependencies
import Foundation
import Testing
import UserNotifications
@testable import AppShared

@MainActor
struct WordSpotlightNotificationTests {
    private var schedule: WordSpotlightSchedule {
        WordSpotlightSchedule.make(profileID: "notification-test", source: "deck", words: [
            SpotlightWord(noteID: 42, term: "cat", reading: "", meaning: "A cat"),
        ], previous: nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func optOutRemovesAnAlertWhoseAddWasAlreadyInFlight() async {
        let pending = LockIsolated<[String]>([])
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer {
            started.continuation.finish()
            release.continuation.finish()
        }
        await withDependencies {
            $0.wordSpotlightNotificationClient.authorizationStatus = { .authorized }
            $0.wordSpotlightNotificationClient.removeRequests = { ids in
                pending.withValue { $0.removeAll { ids.contains($0) } }
            }
            $0.wordSpotlightNotificationClient.addRequest = { request in
                started.continuation.yield()
                var iterator = release.stream.makeAsyncIterator()
                await iterator.next()
                pending.withValue { $0.append(request.identifier) }
            }
        } operation: {
            let notifications = WordSpotlightNotifications()
            var preferences = WordSpotlightPreferences()
            preferences.notifications = true
            let adding = notifications.update(schedule: schedule, preferences: preferences)
            var iterator = started.stream.makeAsyncIterator()
            await iterator.next()
            let clearing = notifications.update(schedule: nil, preferences: WordSpotlightPreferences())
            release.continuation.yield()
            await adding.value
            await clearing.value
            #expect(pending.value.isEmpty)
        }
    }

    @Test(arguments: [UNAuthorizationStatus.denied, .notDetermined, .authorized, .provisional])
    func authorizationControlsDelivery(status: UNAuthorizationStatus) async {
        let pending = LockIsolated<[String]>([])
        await withDependencies {
            $0.wordSpotlightNotificationClient.authorizationStatus = { status }
            $0.wordSpotlightNotificationClient.addRequest = { request in
                pending.withValue { $0.append(request.identifier) }
                #expect(request.content.body == "Take a moment for vocabulary.")
                let rawLink = request.content.userInfo["wordURL"] as? String
                let link = rawLink.flatMap(URL.init(string:)).flatMap(WordSpotlightLink.init(url:))
                #expect(link?.profileID == "notification-test")
                #expect(link?.noteID == 42)
            }
        } operation: {
            var preferences = WordSpotlightPreferences()
            preferences.notifications = true
            preferences.showWord = false
            let notifications = WordSpotlightNotifications()
            await notifications.update(schedule: schedule, preferences: preferences).value
            let allowed = status == .authorized || status == .provisional
            #expect(pending.value.isEmpty == !allowed)
            #expect(notifications.notificationsDenied == (status == .denied))
        }
    }

    @Test func deniedPermissionIsReportedWithoutScheduling() async throws {
        try await withDependencies {
            $0.wordSpotlightNotificationClient.requestPermission = { false }
        } operation: {
            let notifications = WordSpotlightNotifications()
            #expect(try await notifications.requestPermission() == false)
            #expect(notifications.notificationsDenied)
        }
    }
}
