// AmgiApp/Sources/ContentView.swift
import SwiftUI
import AnkiSync
import Sharing

struct ContentView: View {
    @Binding var pendingReviewDeckId: Int64?

    @State private var showSync = false
    @State private var showImport = false
    @State private var refreshID = UUID()
    @State private var importMessage: String?
    @State private var showImportAlert = false

    var body: some View {
        TabView {
            Tab("Decks", systemImage: "rectangle.stack") {
                NavigationStack {
                    DeckListView()
                        .id(refreshID)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showSync = true
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
            Tab("Stats", systemImage: "chart.bar") {
                NavigationStack {
                    StatsDashboardView()
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
        }
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
