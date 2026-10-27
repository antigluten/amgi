public import Dependencies
import DependenciesMacros
import UserNotifications

@DependencyClient
struct WordSpotlightNotificationClient: Sendable {
    var authorizationStatus: @MainActor @Sendable () async -> UNAuthorizationStatus = { .notDetermined }
    var requestPermission: @MainActor @Sendable () async throws -> Bool
    var removeRequests: @MainActor @Sendable (_ identifiers: [String]) -> Void
    var addRequest: @MainActor @Sendable (_ request: UNNotificationRequest) async throws -> Void
}

extension WordSpotlightNotificationClient: DependencyKey {
    static let liveValue = Self(
        authorizationStatus: { await UNUserNotificationCenter.current().notificationSettings().authorizationStatus },
        requestPermission: { try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) },
        removeRequests: { identifiers in
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        },
        addRequest: { try await UNUserNotificationCenter.current().add($0) }
    )

    static let testValue = Self(
        authorizationStatus: { .denied }, requestPermission: { false },
        removeRequests: { _ in }, addRequest: { _ in }
    )
}

extension DependencyValues {
    var wordSpotlightNotificationClient: WordSpotlightNotificationClient {
        get { self[WordSpotlightNotificationClient.self] }
        set { self[WordSpotlightNotificationClient.self] = newValue }
    }
}
