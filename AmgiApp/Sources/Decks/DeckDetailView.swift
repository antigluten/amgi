import SwiftUI
import AmgiTheme
import AnkiKit
import AnkiClients
import Dependencies

struct DeckDetailView: View {
    let deck: DeckInfo
    @Environment(\.palette) private var palette
    @Dependency(\.deckClient) var deckClient
    @State private var counts: DeckCounts = .zero
    @State private var childDecks: [DeckTreeNode] = []
    @State private var showReview = false

    // Custom-study actions
    @State private var showEmptyAlert = false
    @State private var actionInFlight = false
    @State private var actionError: String?
    @State private var rebuildFeedback: String?

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

            if deck.isFiltered {
                Section("Custom Study") {
                    Button {
                        Task { await rebuild() }
                    } label: {
                        Label("Rebuild", systemImage: "arrow.clockwise")
                    }
                    .disabled(actionInFlight)

                    Button(role: .destructive) {
                        showEmptyAlert = true
                    } label: {
                        Label("Empty", systemImage: "tray")
                    }
                    .disabled(actionInFlight)
                }
            }

            if !childDecks.isEmpty {
                Section("Subdecks") {
                    ForEach(childDecks) { child in
                        NavigationLink(value: DeckInfo(id: child.id, name: child.fullName, counts: child.counts, isFiltered: child.isFiltered)) {
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
        .toolbar {
            if deck.isFiltered {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(palette.customStudyBadge, in: RoundedRectangle(cornerRadius: 4))
                        Text(shortTitle)
                            .font(.headline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(shortTitle), custom study deck")
                }
            }
        }
        .fullScreenCover(isPresented: $showReview) {
            ReviewView(deckId: deck.id) {
                showReview = false
                Task { await loadCounts() }
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            ),
            presenting: actionError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .alert(
            "Empty \"\(shortTitle)\"?",
            isPresented: $showEmptyAlert
        ) {
            Button("Empty", role: .destructive) {
                Task { await empty() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Cards will be returned to their home decks.")
        }
        .overlay(alignment: .bottom) {
            if let feedback = rebuildFeedback {
                Text(feedback)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(palette.accent, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: rebuildFeedback)
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

    // MARK: - Custom-study actions

    fileprivate func rebuild() async {
        actionInFlight = true
        defer { actionInFlight = false }
        do {
            let count = try deckClient.rebuildFilteredDeck(deck.id)
            rebuildFeedback = "Rebuilt — \(count) cards"
            await loadCounts()
            try? await Task.sleep(for: .seconds(2))
            rebuildFeedback = nil
        } catch {
            actionError = error.localizedDescription
        }
    }

    fileprivate func empty() async {
        actionInFlight = true
        defer { actionInFlight = false }
        do {
            try deckClient.emptyFilteredDeck(deck.id)
            await loadCounts()
        } catch {
            actionError = error.localizedDescription
        }
    }
}
