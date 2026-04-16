import SwiftUI
import AnkiKit
import AnkiClients
import Dependencies

struct DeckListView: View {
    @Dependency(\.deckClient) var deckClient
    @State private var tree: [DeckTreeNode] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if tree.isEmpty {
                ContentUnavailableView(
                    "No Decks",
                    systemImage: "rectangle.stack",
                    description: Text("Sync with your server to get your decks.")
                )
            } else {
                List {
                    ForEach(tree) { node in
                        DeckRowView(node: node, onMutated: {
                            await loadDecks()
                        })
                    }
                }
                .navigationDestination(for: DeckInfo.self) { deck in
                    DeckDetailView(deck: deck)
                }
                .scrollContentBackground(.hidden)
                .amgiSectionBackground()
            }
        }
        .navigationTitle("Decks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateDeckSheet {
                showCreateSheet = false
                Task { await loadDecks() }
            }
        }
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
    let onMutated: () async -> Void

    @Dependency(\.deckClient) var deckClient
    @State private var showRenameSheet = false
    @State private var showDeleteAlert = false

    var body: some View {
        rowContent
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    showDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)

                Button {
                    showRenameSheet = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(.orange)
            }
            .alert("Delete \"\(node.name)\"?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            try deckClient.delete(node.id)
                        } catch {
                            print("[DeckRowView] Delete failed: \(error)")
                        }
                        await onMutated()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the deck and all its cards.")
            }
            .sheet(isPresented: $showRenameSheet) {
                RenameDeckSheet(deckId: node.id, currentName: node.fullName) {
                    showRenameSheet = false
                    Task { await onMutated() }
                }
            }
    }

    @ViewBuilder
    private var rowContent: some View {
        if node.children.isEmpty {
            NavigationLink(value: deckInfo) {
                rowLabel
            }
        } else {
            DisclosureGroup {
                ForEach(node.children) { child in
                    DeckRowView(node: child, onMutated: onMutated)
                }
            } label: {
                NavigationLink(value: deckInfo) {
                    rowLabel
                }
            }
        }
    }

    private var rowLabel: some View {
        HStack {
            Text(node.name)
                .amgiFont(.body)
                .foregroundStyle(Color.amgiTextPrimary)
            Spacer()
            DeckCountsView(counts: node.counts)
        }
    }

    private var deckInfo: DeckInfo {
        DeckInfo(id: node.id, name: node.fullName, counts: node.counts)
    }
}

// MARK: - CreateDeckSheet

private struct CreateDeckSheet: View {
    let onDone: () -> Void

    @Dependency(\.deckClient) var deckClient
    @State private var name = ""
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Deck name, use :: for subdecks", text: $name)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("New Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await create() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func create() async {
        isSaving = true
        do {
            _ = try deckClient.create(name.trimmingCharacters(in: .whitespaces))
            onDone()
        } catch {
            print("[CreateDeckSheet] Create failed: \(error)")
        }
        isSaving = false
    }
}

// MARK: - RenameDeckSheet

private struct RenameDeckSheet: View {
    let deckId: Int64
    let currentName: String
    let onDone: () -> Void

    @Dependency(\.deckClient) var deckClient
    @State private var name = ""
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Deck name", text: $name)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Rename Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await rename() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .onAppear { name = currentName }
        }
    }

    private func rename() async {
        isSaving = true
        do {
            try deckClient.rename(deckId, name.trimmingCharacters(in: .whitespaces))
            onDone()
        } catch {
            print("[RenameDeckSheet] Rename failed: \(error)")
        }
        isSaving = false
    }
}
