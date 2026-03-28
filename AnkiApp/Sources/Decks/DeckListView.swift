import SwiftUI
import AnkiKit
import AnkiClients
import Dependencies

struct DeckListView: View {
    @Dependency(\.deckClient) var deckClient
    @State private var tree: [DeckTreeNode] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if tree.isEmpty {
                ContentUnavailableView(
                    "No Decks",
                    systemImage: "rectangle.stack",
                    description: Text("Sync with AnkiWeb to get your decks.")
                )
            } else {
                List {
                    ForEach(tree) { node in
                        DeckRowView(node: node)
                    }
                }
                .navigationDestination(for: DeckInfo.self) { deck in
                    DeckDetailView(deck: deck)
                }
            }
        }
        .navigationTitle("Decks")
        .task {
            await loadDecks()
        }
        .refreshable {
            await loadDecks()
        }
    }

    private func loadDecks() async {
        do {
            tree = try deckClient.fetchTree()
        } catch {
            print("[DeckListView] Error loading decks: \(error)")
            tree = []
        }
        isLoading = false
    }
}

// MARK: - DeckRowView

private struct DeckRowView: View {
    let node: DeckTreeNode

    var body: some View {
        if node.children.isEmpty {
            NavigationLink(value: deckInfo) {
                rowContent
            }
        } else {
            DisclosureGroup {
                ForEach(node.children) { child in
                    DeckRowView(node: child)
                }
            } label: {
                NavigationLink(value: deckInfo) {
                    rowContent
                }
            }
        }
    }

    private var rowContent: some View {
        HStack {
            Text(node.name)
            Spacer()
            DeckCountsView(counts: node.counts)
        }
    }

    private var deckInfo: DeckInfo {
        DeckInfo(id: node.id, name: node.fullName, counts: node.counts)
    }
}
