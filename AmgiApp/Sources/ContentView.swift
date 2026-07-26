// AmgiApp/Sources/ContentView.swift
import SwiftUI
import AnkiKit
import AnkiSync
import Sharing
import Dependencies

/// App root. Hosts the tab bar (`MainTabView`) and orchestrates the
/// cross-cutting flows that sit above it: sync (sheet + toast), deck
/// import, and the review cover. Each flow lives in its own piece —
/// `MainTabView`, `SyncToastController`, `deckImport` — so the body stays a
/// thin composition.
struct ContentView: View {
    @Binding var pendingReviewDeckId: DeckID?

    @Dependency(\.syncCoordinator) private var coordinator

    @State private var syncToast = SyncToastController()
    @State private var showSync = false
    @State private var showImport = false
    @State private var refreshID = UUID()

    @Shared(.appStorage(ReaderPreferences.Keys.showTab))
    private var showReaderTab: Bool = true

    var body: some View {
        MainTabView(
            refreshID: refreshID,
            showReaderTab: showReaderTab,
            onSync: startSync,
            onImport: { showImport = true },
            onSelectStudyDeck: { pendingReviewDeckId = $0 }
        )
        .sheet(isPresented: $showSync) {
            refreshID = UUID()
        } content: {
            SyncSheet(isPresented: $showSync)
                .presentationDetents([.fraction(0.7), .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: SyncToastController.needsAttention(coordinator.state)) { _, needs in
            if needs { showSync = true }
        }
        .onChange(of: coordinator.state) { _, newState in
            syncToast.handle(newState)
        }
        .syncToastOverlay(syncToast.toast)
        .deckImport(isPresented: $showImport) {
            refreshID = UUID()
        }
        .fullScreenCover(item: $pendingReviewDeckId) { deckId in
            ReviewView(deckId: deckId) {
                pendingReviewDeckId = nil
                refreshID = UUID()
            }
        }
    }

}

private extension ContentView {
    func startSync() {
        syncToast.presentSyncing()
        Task { await coordinator.startSync() }
    }
}
