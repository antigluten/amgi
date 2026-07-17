// AmgiApp/Sources/ContentView.swift
import SwiftUI
import AnkiSync
import Sharing
import Dependencies

struct ContentView: View {
    @Binding var pendingReviewDeckId: Int64?

    @Dependency(\.syncCoordinator) private var coordinator

    @State private var showSync = false
    @State private var showImport = false
    @State private var refreshID = UUID()
    @State private var importMessage: String?
    @State private var showImportAlert = false
    @State private var toast: SyncToast.Kind?
    @State private var toastDismissTask: Task<Void, Never>?

    @Shared(.appStorage(ReaderPreferences.Keys.showTab))
    private var showReaderTab: Bool = true

    var body: some View {
        TabView {
            Tab("Decks", systemImage: "rectangle.stack") {
                NavigationStack {
                    DeckListView()
                        .id(refreshID)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                ProfilePickerMenu()
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    presentSyncingToast()
                                    Task { await coordinator.startSync() }
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showImport = true
                                } label: {
                                    Image(systemName: "square.and.arrow.down")
                                }
                            }
                        }
                }
            }
            Tab(role: .search) {
                NavigationStack {
                    BrowseView()
                        .id(refreshID)
                }
            }
            if showReaderTab {
                Tab("Reader", systemImage: "books.vertical") {
                    NavigationStack {
                        ReaderLibraryView()
                            .id(refreshID)
                    }
                }
            }
            Tab("Stats", systemImage: "chart.bar") {
                NavigationStack {
                    StatsDashboardView()
                        .id(refreshID)
                }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView()
                        .id(refreshID)
                }
            }
            #if DEBUG
            Tab("Debug", systemImage: "wrench.and.screwdriver") {
                NavigationStack {
                    DebugView()
                        .id(refreshID)
                }
            }
            #endif
        }
        .sheet(isPresented: $showSync) {
            refreshID = UUID()
        } content: {
            SyncSheet(isPresented: $showSync)
                .presentationDetents([.fraction(0.7), .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: stateNeedsAttention(coordinator.state)) { _, needs in
            if needs { showSync = true }
        }
        .onChange(of: coordinator.state) { _, newState in
            handleSyncStateChange(newState)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                SyncToast(kind: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: toast)
        .fileImporter(isPresented: $showImport, allowedContentTypes: [.data]) { result in
            handleImport(result)
        }
        .alert("Import", isPresented: $showImportAlert) {
            Button("OK") { }
        } message: {
            Text(importMessage ?? "")
        }
        .fullScreenCover(item: $pendingReviewDeckId) { deckId in
            ReviewView(deckId: deckId) {
                pendingReviewDeckId = nil
                refreshID = UUID()
            }
        }
    }

    private func stateNeedsAttention(_ state: SyncCoordinator.SyncState) -> Bool {
        switch state {
        case .needsFullSync, .error: return true
        default: return false
        }
    }

    private func presentSyncingToast() {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        toast = .progress("Syncing\u{2026}")
    }

    private func handleSyncStateChange(_ state: SyncCoordinator.SyncState) {
        switch state {
        case .syncing(let message):
            toastDismissTask?.cancel()
            toastDismissTask = nil
            toast = .progress(message.isEmpty ? "Syncing\u{2026}" : message)
        case .syncingMedia(let total, let downloaded):
            toastDismissTask?.cancel()
            toastDismissTask = nil
            toast = .progress("Media \(downloaded)/\(total)")
        case .success(let summary):
            toast = .success(SyncToast.summaryMessage(for: summary))
            toastDismissTask?.cancel()
            toastDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled { toast = nil }
            }
        case .needsFullSync, .error, .noServer, .idle:
            toastDismissTask?.cancel()
            toastDismissTask = nil
            toast = nil
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let ext = url.pathExtension.lowercased()
            guard ext == "apkg" || ext == "colpkg" else {
                importMessage = "Unsupported file type. Please select an .apkg or .colpkg file."
                showImportAlert = true
                return
            }
            do {
                let summary = try ImportHelper.importPackage(from: url)
                importMessage = summary
                refreshID = UUID()
            } catch {
                importMessage = "Import failed: \(error.localizedDescription)"
            }
            showImportAlert = true
        case .failure(let error):
            importMessage = "Could not select file: \(error.localizedDescription)"
            showImportAlert = true
        }
    }
}

extension Int64: @retroactive Identifiable {
    public var id: Int64 { self }
}
