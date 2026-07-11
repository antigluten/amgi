// AmgiApp/Sources/MainTabView.swift
import SwiftUI
import AnkiKit

/// Root tab bar for the app. Pure layout: each tab wraps a feature view in
/// a `NavigationStack`. `refreshID` (bumped by the host after sync / import /
/// review) now only drives the tabs not yet on `CollectionStore` — Library
/// and Study reload via the store's generation instead. All side effects are
/// forwarded to the host via closures so this view owns no I/O or sync state.
struct MainTabView: View {
    let refreshID: UUID
    let showReaderTab: Bool
    let onSync: () -> Void
    let onImport: () -> Void
    let onSelectStudyDeck: (DeckID) -> Void

    var body: some View {
        TabView {
            // 1. Library
            Tab("Library", systemImage: "books.vertical") {
                NavigationStack {
                    DeckListView()
                        .toolbar { libraryToolbar }
                }
            }
            // 2. Reader
            if showReaderTab {
                Tab("Read", systemImage: "book") {
                    NavigationStack {
                        ReaderLibraryView()
                            .id(refreshID)
                    }
                }
            }
            // 3. Study
            Tab("Study", systemImage: "graduationcap") {
                NavigationStack {
                    StudyLandingView(onSelectDeck: onSelectStudyDeck)
                }
            }
            // 4. Stats
            Tab("Stats", systemImage: "chart.bar") {
                NavigationStack {
                    StatsDashboardView()
                        .id(refreshID)
                }
            }
            // 5. Settings
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView()
                        .id(refreshID)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var libraryToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onSync) {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onImport) {
                Image(systemName: "square.and.arrow.down")
            }
        }
    }
}
