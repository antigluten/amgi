import AnkiClients
import AnkiKit
import AnkiSync
import Dependencies
import SwiftUI

struct WatchDeckListView: View {
    @Dependency(\.deckClient) var deckClient
    @State private var tree: [DeckTreeNode] = []
    @State private var isLoading = true
    @State private var expandedDecks: Set<Int64> = []
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if tree.isEmpty {
                Text("No Decks")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(flattenedItems) { item in
                        WatchDeckRow(
                            node: item.node,
                            depth: item.depth,
                            isExpanded: expandedDecks.contains(item.id),
                            onToggle: { toggleExpansion(item.id) }
                        )
                    }
                }
                .refreshable {
                    await loadDecks()
                }
            }
        }
        .navigationTitle("Decks")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(destination: WatchStatsView()) {
                    Image(systemName: "chart.bar.fill")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSyncMenu = true
                } label: {
                    if isSyncing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isSyncing || isLoading)
            }
        }
        .sheet(isPresented: $showSyncMenu) {
            // WatchOS sheet: minimal actions
            VStack {
                Button("Sync") {
                    showSyncMenu = false
                    Task { await sync() }
                }
                Button("Sign out", role: .destructive) {
                    showSyncMenu = false
                    showLoginSheet = true
                }
            }
            .padding()
        }
        .sheet(isPresented: $showLoginSheet) {
            // Present login flow immediately after sign-out
            WatchLoginView(onLoginSuccess: {
                showLoginSheet = false
                Task { await loadDecks() }
            })
        }
        .task {
            await loadDecks()
        }
    }
    @Dependency(\.syncClient) var syncClient
    @State private var isSyncing = false
    @State private var showSyncMenu = false
    @State private var showLoginSheet = false
    private func sync() async {
        isSyncing = true
        do {
            _ = try await syncClient.sync()
            await loadDecks()
        } catch {
            print("[WatchDeckList] Sync failed: \(error)")
        }
        isSyncing = false
    }
    private func loadDecks() async {
        do {
            tree = try deckClient.fetchTree()
        } catch {
            tree = []
        }
        isLoading = false
    }
    private func toggleExpansion(_ id: Int64) {
        if expandedDecks.contains(id) {
            expandedDecks.remove(id)
        } else {
            expandedDecks.insert(id)
        }
    }
    // MARK: - Flattened view support for collapsible hierarchy
    private struct FlattenedItem: Identifiable {
        let id: Int64
        let node: DeckTreeNode
        let depth: Int
    }
    private var flattenedItems: [FlattenedItem] {
        flatten(tree)
    }
    private func flatten(_ nodes: [DeckTreeNode], depth: Int = 0) -> [FlattenedItem] {
        nodes.flatMap { node -> [FlattenedItem] in
            var result: [FlattenedItem] = [FlattenedItem(id: node.id, node: node, depth: depth)]
            if expandedDecks.contains(node.id) {
                result.append(contentsOf: flatten(node.children, depth: depth + 1))
            }
            return result
        }
    }
    // Sign-out no longer clears credentials; login is handled by the login view
}
extension DeckTreeNode {
    func toDeckInfo() -> DeckInfo {
        DeckInfo(id: self.id, name: self.fullName, counts: self.counts)
    }
}
private struct WatchDeckRow: View {
    let node: DeckTreeNode
    let depth: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    // Indentation per depth level (modifiable to adjust layout density)
    static let indentPerLevel: CGFloat = 10
    var body: some View {
        HStack {
            // Text content is left-aligned; chevron is right-aligned for collapsible nodes
            NavigationLink(value: node.toDeckInfo()) {
                VStack(alignment: .leading) {
                    Text(node.name.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.body)
                    DeckCountsView(counts: node.counts)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !node.children.isEmpty {
                Button(action: onToggle) {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, CGFloat(depth) * Self.indentPerLevel)
    }
}
