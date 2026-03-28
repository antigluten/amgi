import SwiftUI
import AnkiSync

struct ContentView: View {
    @State private var showSync = false
    @State private var refreshID = UUID()

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
        }
        .sheet(isPresented: $showSync) {
            refreshID = UUID()
        } content: {
            SyncSheet(isPresented: $showSync)
        }
    }
}
