//
//  RootView.swift
//  RootFeature
//
//  Created by Vladimir Gusev on 29.08.2026.
//

public import SwiftUI
import AppCore
import AppShared
import Theme
import AnkiKit
import Dependencies
import Foundation
import ReaderFeature
import ReviewFeature
import Sharing
import SyncFeature
import SettingsFeature

/// The app's whole view composition. The host target supplies only `@main`.
///
/// Owns the routing between onboarding, the tab bar, and the startup-error
/// screen; the cross-cutting flows above the tabs (sync, deck import, the
/// review cover); and the root chrome (`.themedRoot()`, the app font, the
/// profile re-id, the deep link, the scene-phase widget refresh).
public struct RootView: View {
    public init() {}

    @Shared(.onboardingCompleted) private var onboardingCompleted
    @Environment(\.scenePhase) private var scenePhase
    @Shared(.appStorage(AppearancePreferences.Keys.appFont))
    private var appFontRaw: String = AppFont.system.rawValue

    @Dependency(\.collectionStore) private var store
    @Bindable private var accountStore = AccountStore.shared

    @State private var pendingReviewDeckId: DeckID?
    @State private var showImport = false
    @State private var refreshID = UUID()
    @State private var wordSheet: WordSpotlightSheet?
    private let wordSpotlight = WordSpotlightController.shared

    @Shared(.appStorage(ReaderPreferences.Keys.showTab))
    private var showReaderTab: Bool = true

    public var body: some View {
        routed
            // Rebuild the entire view tree when the active profile changes —
            // every screen holds state derived from the previously open
            // collection. `.id(_:)` sets identity for `routed` and its
            // subtree only; it does not touch state held on `RootView`
            // itself, so `pendingReviewDeckId` needs the explicit clear
            // below.
            .id(accountStore.selectedID)
            .onChange(of: accountStore.selectedID) {
                pendingReviewDeckId = nil
                wordSheet = nil
            }
            .task(id: store.generation) {
                guard AmgiRoot.startupError == nil else { return }
                await wordSpotlight.refresh()
            }
            .onChange(of: wordSpotlight.pendingLink, initial: true) { _, link in
                guard let link else { return }
                wordSheet = .word(link)
                wordSpotlight.pendingLink = nil
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await writeWidgetSnapshot() }
                    Task { await wordSpotlight.refresh() }
                }
            }
            .onOpenURL { url in
                if let link = WordSpotlightLink(url: url) {
                    wordSheet = .word(link)
                    return
                }
                if url.scheme == "amgi", url.host == "word-settings" {
                    wordSheet = .settings
                    return
                }
                guard url.scheme == "amgi",
                      url.host == "review",
                      let deckIdStr = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "deckId" })?.value,
                      let deckId = Int64(deckIdStr)
                else { return }
                pendingReviewDeckId = DeckID(deckId)
            }
            .sheet(item: $wordSheet) { spotlightSheet($0) }
            .themedRoot()
            .environment(\.appFont, AppFont(rawValue: appFontRaw) ?? .system)
    }

    private func spotlightSheet(_ destination: WordSpotlightSheet) -> some View {
        NavigationStack {
            Group {
                switch destination {
                case .settings: WordSpotlightSettingsView()
                case .word(let link): WordSpotlightDetailView(link: link)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { wordSheet = nil }
                        .accessibilityIdentifier("wordSpotlight.dismiss")
                }
            }
        }
    }

    @ViewBuilder
    private var routed: some View {
        if let startupError = AmgiRoot.startupError {
            StartupErrorView(message: startupError)
        } else if onboardingCompleted {
            main
        } else {
            OnboardingView()
        }
    }

    private var main: some View {
        MainTabView(
            refreshID: refreshID,
            showReaderTab: showReaderTab,
            onImport: { showImport = true },
            onSelectStudyDeck: { pendingReviewDeckId = $0 }
        )
        .alert(
            "Couldn't switch profile",
            isPresented: $accountStore.hasSwitchFailure
        ) {
            Button("OK", role: .cancel) { accountStore.switchFailure = nil }
        } message: {
            Text(accountStore.switchFailure ?? "")
        }
        // still drives the tabs not yet on CollectionStore
        .syncFlow { refreshID = UUID() }
        .deckImport(isPresented: $showImport) {
            store.invalidateAll()
            refreshID = UUID()
        }
        .fullScreenCover(item: $pendingReviewDeckId) { deckId in
            ReviewView(deckId: deckId) {
                pendingReviewDeckId = nil
                store.invalidateAll()
                refreshID = UUID()
            }
        }
        .environment(\.lookupPopup, ReaderLookupPopup())
        .environment(\.dictionarySettings, ReaderDictionarySettings())
    }
}

private enum WordSpotlightSheet: Identifiable {
    case settings
    case word(WordSpotlightLink)

    var id: String {
        switch self {
        case .settings: "settings"
        case .word(let link): link.url?.absoluteString ?? "word"
        }
    }
}
