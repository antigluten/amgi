//
//  WatchDeckListView.swift
//  WatchFeature
//
//  Created by Leaf Eriksen on 17.07.2026.
//

import AnkiClients
import AnkiKit
import AnkiSync
import Dependencies
import os
import SwiftUI

private let logger = Logger(subsystem: "com.amgiapp.AmgiApp", category: "WatchDeckList")

struct WatchDeckListView: View {
    @Dependency(\.deckClient) var deckClient
    @Dependency(\.syncClient) var syncClient
    /// One axis instead of `isLoading` + a `tree` that was also emptied on
    /// failure, which made "your collection has no decks" and "the fetch
    /// threw" render as the same screen.
    enum LoadState {
        case loading
        case loaded([DeckTreeNode])
        case failed
    }

    /// The two sheets are mutually exclusive; as separate flags they could
    /// both be raised at once. Plain `Equatable` rather than `@CasePathable`
    /// so the watch target doesn't have to link SwiftUINavigation.
    enum Destination: Hashable, Identifiable {
        case syncMenu
        case login

        var id: Self { self }
    }

    @State private var state: LoadState = .loading
    @State private var expandedDecks: Set<DeckID> = []
    @State private var isSyncing = false
    @State private var destination: Destination?
    @State private var rows: [FlattenedItem] = []

    private var tree: [DeckTreeNode] {
        if case .loaded(let tree) = state { return tree }
        return []
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed:
                ContentUnavailableView {
                    Label("Couldn't Load Decks", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("The collection couldn't be read.")
                } actions: {
                    Button("Try Again") { Task { await loadDecks() } }
                }
            case .loaded(let loaded) where loaded.isEmpty:
                ContentUnavailableView {
                    Label("No Decks", systemImage: "rectangle.stack")
                } description: {
                    Text("Sync to bring your decks over from iPhone.")
                } actions: {
                    Button("Sync") { Task { await sync() } }
                        .disabled(isSyncing)
                }
            case .loaded:
                List {
                    ForEach(rows) { item in
                        WatchDeckRow(
                            name: item.name,
                            counts: item.counts,
                            deck: item.deck,
                            hasChildren: item.hasChildren,
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
                NavigationLink {
                    WatchStatsView()
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .accessibilityLabel("Stats")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    destination = .syncMenu
                } label: {
                    if isSyncing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .accessibilityLabel(isSyncing ? "Syncing" : "Sync")
                .disabled(isSyncing || isLoadingDecks)
            }
        }
        .sheet(item: $destination) { target in
            switch target {
            case .syncMenu:
                // WatchOS sheet: minimal actions
                VStack {
                    Button("Sync") {
                        destination = nil
                        Task { await sync() }
                    }
                    Button("Switch Account") {
                        destination = .login
                    }
                }
                .padding()
            case .login:
                WatchLoginView(onLoginSuccess: {
                    destination = nil
                    Task { await loadDecks() }
                })
            }
        }
        .task {
            await loadDecks()
        }
    }

    private func sync() async {
        isSyncing = true
        do {
            _ = try await syncClient.sync()
            await loadDecks()
        } catch {
            logger.error("Sync error: \(error)")
        }
        isSyncing = false
    }

    private var isLoadingDecks: Bool {
        if case .loading = state { return true }
        return false
    }

    private func loadDecks() async {
        do {
            state = .loaded(try await deckClient.fetchTree())
        } catch {
            logger.error("Deck load error: \(error)")
            state = .failed
        }
        rebuildRows()
    }
    private func toggleExpansion(_ id: DeckID) {
        if expandedDecks.contains(id) {
            expandedDecks.remove(id)
        } else {
            expandedDecks.insert(id)
        }
        rebuildRows()
    }
    // MARK: - Flattened view support for collapsible hierarchy
    private struct FlattenedItem: Identifiable {
        let id: DeckID
        let name: String
        let counts: DeckCounts
        let deck: DeckInfo
        let hasChildren: Bool
        let depth: Int
    }
    private func rebuildRows() {
        rows = flatten(tree)
    }
    private func flatten(_ nodes: [DeckTreeNode], depth: Int = 0) -> [FlattenedItem] {
        nodes.flatMap { node -> [FlattenedItem] in
            var result = [
                FlattenedItem(
                    id: node.id,
                    name: node.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    counts: node.counts,
                    deck: node.asDeckInfo,
                    hasChildren: !node.children.isEmpty,
                    depth: depth
                )
            ]
            if expandedDecks.contains(node.id) {
                result.append(contentsOf: flatten(node.children, depth: depth + 1))
            }
            return result
        }
    }
}
private struct WatchDeckRow: View {
    let name: String
    let counts: DeckCounts
    let deck: DeckInfo
    let hasChildren: Bool
    let depth: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    // Indentation per depth level (modifiable to adjust layout density)
    static let indentPerLevel: CGFloat = 12
    var body: some View {
        HStack {
            // Text content is left-aligned; chevron is right-aligned for collapsible nodes
            NavigationLink(value: deck) {
                VStack(alignment: .leading) {
                    Text(name)
                        .font(.body)
                    DeckCountsView(counts: counts)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if hasChildren {
                Button(action: onToggle) {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Subdecks")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            }
        }
        .padding(.leading, CGFloat(depth) * Self.indentPerLevel)
    }
}
