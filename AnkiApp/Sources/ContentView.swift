import SwiftUI
import AnkiSync

struct ContentView: View {
    @State private var showSync = false
    @State private var refreshID = UUID()

    private var isLocalMode: Bool {
        UserDefaults.standard.string(forKey: "syncMode") == "local"
    }

    var body: some View {
        TabView {
            Tab("Decks", systemImage: "rectangle.stack") {
                NavigationStack {
                    DeckListView()
                        .id(refreshID)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                if isLocalMode {
                                    Button {
                                        showImport = true
                                    } label: {
                                        Image(systemName: "square.and.arrow.down")
                                    }
                                } else {
                                    Button {
                                        showSync = true
                                    } label: {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                    }
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
    }
}
