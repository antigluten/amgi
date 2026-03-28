import SwiftUI
import AnkiKit
import AnkiClients
import Dependencies

struct DeckDetailView: View {
    let deck: DeckInfo
    @Dependency(\.deckClient) var deckClient
    @State private var counts: DeckCounts = .zero
    @State private var childDecks: [DeckTreeNode] = []
    @State private var showReview = false

    private var shortTitle: String {
        String(deck.name.split(separator: "::", omittingEmptySubsequences: true).last ?? Substring(deck.name))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("New")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(counts.newCount)")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Learning")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(counts.learnCount)")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Review")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(counts.reviewCount)")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Button {
                    showReview = true
                } label: {
                    Label("Study Now", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .disabled(counts.total == 0)
            }

            if !childDecks.isEmpty {
                Section("Subdecks") {
                    ForEach(childDecks) { child in
                        NavigationLink(value: DeckInfo(id: child.id, name: child.fullName, counts: child.counts)) {
                            HStack {
                                Text(child.name)
                                Spacer()
                                DeckCountsView(counts: child.counts)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(shortTitle)
        .fullScreenCover(isPresented: $showReview) {
            ReviewView(deckId: deck.id) {
                showReview = false
                Task { await loadCounts() }
            }
        }
        .task {
            await loadCounts()
            await loadChildren()
        }
    }

    private func loadCounts() async {
        do {
            counts = try deckClient.countsForDeck(deck.id)
            print("[DeckDetail] Counts for '\(deck.name)' (\(deck.id)): new=\(counts.newCount), learn=\(counts.learnCount), review=\(counts.reviewCount)")
        } catch {
            print("[DeckDetail] Error loading counts for '\(deck.name)': \(error)")
            counts = .zero
        }
    }

    private func loadChildren() async {
        do {
            let tree = try deckClient.fetchTree()
            childDecks = findChildren(in: tree, parentId: deck.id)
        } catch {
            childDecks = []
        }
    }

    private func findChildren(in nodes: [DeckTreeNode], parentId: Int64) -> [DeckTreeNode] {
        for node in nodes {
            if node.id == parentId { return node.children }
            let found = findChildren(in: node.children, parentId: parentId)
            if !found.isEmpty { return found }
        }
        return []
    }
}
