// AmgiApp/Sources/AmgiAppApp.swift
import BackgroundTasks
import SwiftUI
import AnkiBackend
import AnkiSync
import Dependencies
import Foundation
import Sharing

@main
struct AnkiAppApp: App {
    @Shared(.onboardingCompleted) private var onboardingCompleted
    @Environment(\.scenePhase) private var scenePhase
    @State private var pendingReviewDeckId: Int64? = nil

    private var destination: Destination {
        onboardingCompleted ? .main : .onboarding
    }

    init() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.amgiapp.AmgiApp.widget-refresh",
            using: nil
        ) { @Sendable task in
            handleWidgetRefreshTask(task)
        }
        scheduleWidgetRefreshTask()

        try! prepareDependencies {
            let backend = try AnkiBackend(preferredLangs: ["en"])

            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!
            let ankiDir = appSupport.appendingPathComponent("AnkiCollection", isDirectory: true)
            try FileManager.default.createDirectory(at: ankiDir, withIntermediateDirectories: true)

            let collectionPath = ankiDir.appendingPathComponent("collection.anki2").path
            let mediaPath = ankiDir.appendingPathComponent("media").path
            let mediaDbPath = ankiDir.appendingPathComponent("media.db").path
            try FileManager.default.createDirectory(
                atPath: mediaPath, withIntermediateDirectories: true
            )

            try backend.openCollection(
                collectionPath: collectionPath,
                mediaFolderPath: mediaPath,
                mediaDbPath: mediaDbPath
            )
            try? backend.checkDatabase()
            $0.ankiBackend = backend
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch destination {
                case .onboarding:
                    OnboardingView()
                case .main:
                    ContentView(pendingReviewDeckId: $pendingReviewDeckId)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await writeWidgetSnapshot() }
                }
            }
            .onOpenURL { url in
                guard url.scheme == "amgi",
                      url.host == "review",
                      let deckIdStr = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "deckId" })?.value,
                      let deckId = Int64(deckIdStr)
                else { return }
                pendingReviewDeckId = deckId
            }
        }
    }
}

private extension AnkiAppApp {
    enum Destination {
        case onboarding
        case main
    }
}

private struct UncheckedSendableBox<T>: @unchecked Sendable { let value: T }

private func handleWidgetRefreshTask(_ task: BGTask) {
    let box = UncheckedSendableBox(value: task)
    let work = Task {
        await writeWidgetSnapshot()
        box.value.setTaskCompleted(success: true)
        scheduleWidgetRefreshTask()
    }
    task.expirationHandler = {
        work.cancel()
        box.value.setTaskCompleted(success: false)
    }
}

/// Schedules a BGAppRefreshTask to fire shortly after the next midnight.
/// The task writes a fresh widget snapshot so the widget shows today's counts
/// even if the user hasn't opened the app yet.
private func scheduleWidgetRefreshTask() {
    let request = BGAppRefreshTaskRequest(identifier: "com.amgiapp.AmgiApp.widget-refresh")
    let cal = Calendar.current
    let tomorrow = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    // Fire 5 minutes after midnight so Anki's day rollover has settled.
    request.earliestBeginDate = cal.date(byAdding: .minute, value: 5, to: tomorrow) ?? tomorrow
    try? BGTaskScheduler.shared.submit(request)
}
