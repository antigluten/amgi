import SwiftUI
import AnkiKit
import AnkiClients
import AnkiServices
import Dependencies
import AmgiTheme

enum BrowseSortOrder: String, CaseIterable, Sendable {
    case dateDesc = "Date (newest)"
    case titleAsc = "Title (A→Z)"
    case templateAsc = "Type (A→Z)"
}

struct BrowseView: View {
    @Dependency(\.noteClient) var noteClient
    @Dependency(\.deckClient) var deckClient
    @Dependency(\.cardClient) var cardClient
    @Dependency(\.tagClient) var tagClient
    @Dependency(\.notetypesService) var notetypesService

    @State private var searchText = ""
    @State private var allNotes: [NoteRecord] = []
    @State private var notes: [NoteRecord] = []
    @State private var allDecks: [DeckInfo] = []
    /// The top-level parent deck selected (stays set even when drilling into subdecks)
    @State private var parentDeck: DeckInfo?
    /// The actual deck filter applied (could be parent or a subdeck)
    @State private var activeDeck: DeckInfo?
    @State private var isLoading = false
    @State private var hasMorePages = true
    @State private var showAddNote = false
    @State private var showAddImageOcclusion = false
    @State private var selectionState = BrowseSelectionState()
    @State private var showTagSheet = false
    @State private var showDeleteConfirm = false
    @State private var pendingSwipeDelete: NoteRecord?
    @State private var allTags: [String] = []
    @State private var activeTag: String?
    @State private var sortOrder: BrowseSortOrder = .dateDesc
    @State private var notetypeNames: [Int64: String] = [:]

    private let pageSize = 50

    var body: some View {
        Group {
            if notes.isEmpty && !isLoading && searchText.isEmpty && activeDeck == nil {
                ContentUnavailableView(
                    "Browse Notes",
                    systemImage: "magnifyingglass",
                    description: Text("Search by content, tags, or filter by deck.")
                )
            } else if notes.isEmpty && !isLoading {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(sortedNotes(notes), id: \.id) { note in
                        HStack {
                            if selectionState.isSelectMode {
                                Image(systemName: selectionState.contains(note.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectionState.contains(note.id) ? Color.accentColor : Color.secondary)
                                NoteRowView(note: note, notetypeName: notetypeNames[note.mid])
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectionState.toggle(note.id)
                                    }
                                    .onAppear {
                                        if note.sfld == "Loading..." {
                                            Task { await fetchNoteDetails(id: note.id) }
                                        }
                                        if note.id == notes.last?.id {
                                            Task { await loadNextPage() }
                                        }
                                    }
                            } else {
                                HStack {
                                    NavigationLink(value: note) {
                                        NoteRowView(note: note, notetypeName: notetypeNames[note.mid])
                                            .onAppear {
                                                // Lazy-load stub notes when they appear on screen
                                                if note.sfld == "Loading..." {
                                                    Task { await fetchNoteDetails(id: note.id) }
                                                }
                                                // Paging: load next batch near the end
                                                if note.id == notes.last?.id {
                                                    Task { await loadNextPage() }
                                                }
                                            }
                                    }
                                    NoteContextMenuButton(noteId: note.id) {
                                        Task { await performSearch() }
                                    }
                                }
                                .contentShape(Rectangle())
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    selectionState.enterSelectMode(preselect: note.id)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingSwipeDelete = note
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                .navigationDestination(for: NoteRecord.self) { note in
                    // If tapped a stub, fetch full details first
                    let resolvedNote = (note.sfld == "Loading...")
                        ? (try? noteClient.fetch(note.id)) ?? note
                        : note
                    NoteEditingDestinationView(note: resolvedNote) {
                        Task { await performSearch() }
                    }
                }
            }
        }
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("Add Note") { showAddNote = true }
                    Button("Add Image Occlusion") { showAddImageOcclusion = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(BrowseSortOrder.allCases, id: \.self) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            if sortOrder == order {
                                Label(order.rawValue, systemImage: "checkmark")
                            } else {
                                Text(order.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .disabled(notes.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if selectionState.isSelectMode {
                    Button("Done") {
                        selectionState.exitSelectMode()
                    }
                } else if !notes.isEmpty {
                    Button("Edit") {
                        selectionState.enterSelectMode()
                    }
                }
            }
            if selectionState.isSelectMode {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        suspendSelected()
                    } label: {
                        Label("Suspend", systemImage: "pause.circle")
                    }
                    .disabled(selectionState.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Spacer()
                }
                ToolbarItem(placement: .bottomBar) {
                    Menu {
                        Button { flagSelected(1) } label: { Label("Red flag",       systemImage: "flag.fill") }
                        Button { flagSelected(2) } label: { Label("Orange flag",    systemImage: "flag.fill") }
                        Button { flagSelected(3) } label: { Label("Green flag",     systemImage: "flag.fill") }
                        Button { flagSelected(4) } label: { Label("Blue flag",      systemImage: "flag.fill") }
                        Button { flagSelected(5) } label: { Label("Pink flag",      systemImage: "flag.fill") }
                        Button { flagSelected(6) } label: { Label("Turquoise flag", systemImage: "flag.fill") }
                        Button { flagSelected(7) } label: { Label("Purple flag",    systemImage: "flag.fill") }
                        Divider()
                        Button { flagSelected(0) } label: { Label("Clear flag",     systemImage: "flag.slash") }
                    } label: {
                        Label("Flag", systemImage: "flag")
                    }
                    .disabled(selectionState.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Spacer()
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showTagSheet = true
                    } label: {
                        Label("Tags", systemImage: "tag")
                    }
                    .disabled(selectionState.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Spacer()
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selectionState.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showAddNote) {
            AddNoteView {
                Task { await performSearch() }
            }
        }
        .sheet(isPresented: $showAddImageOcclusion) {
            AddImageOcclusionNoteView { Task { await performSearch() } }
        }
        .sheet(isPresented: $showTagSheet) {
            BatchTagSheet(noteIDs: selectionState.selectedNoteIDs) {
                Task {
                    await MainActor.run {
                        selectionState.exitSelectMode()
                    }
                    await performSearch()
                }
            }
        }
        .confirmationDialog(
            "Delete this note?",
            isPresented: Binding(
                get: { pendingSwipeDelete != nil },
                set: { if !$0 { pendingSwipeDelete = nil } }
            ),
            presenting: pendingSwipeDelete
        ) { note in
            Button("Delete", role: .destructive) {
                Task {
                    try? noteClient.delete(note.id)
                    pendingSwipeDelete = nil
                    await performSearch()
                }
            }
            Button("Cancel", role: .cancel) {
                pendingSwipeDelete = nil
            }
        } message: { _ in
            Text("This action cannot be undone.")
        }
        .confirmationDialog(
            "Delete \(selectionState.count) note\(selectionState.count == 1 ? "" : "s")?",
            isPresented: $showDeleteConfirm
        ) {
            Button("Delete", role: .destructive) {
                deleteSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .safeAreaInset(edge: .top) {
            if !allDecks.isEmpty || !allTags.isEmpty {
                filterBar
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search notes...")
        .onChange(of: searchText) {
            Task { await performSearch() }
        }
        .onChange(of: activeDeck) {
            Task { await performSearch() }
        }
        .onChange(of: activeTag) {
            Task { await performSearch() }
        }
        .task {
            await loadDecks()
            await performSearch()
            allTags = ((try? tagClient.getAllTags()) ?? []).sorted()
            if let pairs = try? notetypesService.getNotetypeNames() {
                notetypeNames = Dictionary(uniqueKeysWithValues: pairs.map { ($0.id, $0.name) })
            }
        }
    }

    // MARK: - Sort

    private func sortedNotes(_ notes: [NoteRecord]) -> [NoteRecord] {
        switch sortOrder {
        case .dateDesc:
            return notes.sorted { $0.mod > $1.mod }
        case .titleAsc:
            return notes.sorted { $0.sfld.localizedCaseInsensitiveCompare($1.sfld) == .orderedAscending }
        case .templateAsc:
            return notes.sorted { (notetypeNames[$0.mid] ?? "") < (notetypeNames[$1.mid] ?? "") }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 0) {
            if !allDecks.isEmpty {
                deckFilterBar
            }
            if !allTags.isEmpty {
                tagChipRow
            }
        }
    }

    private var tagChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "All", isSelected: activeTag == nil) {
                    activeTag = nil
                }
                ForEach(allTags, id: \.self) { tag in
                    chipButton(label: tag, isSelected: activeTag == tag) {
                        activeTag = (activeTag == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Deck Filter

    private var topLevelDecks: [DeckInfo] {
        allDecks.filter { !$0.name.contains("::") }
    }

    /// Direct children of the parent deck (shown as second row)
    private var childDecks: [DeckInfo] {
        guard let parent = parentDeck else { return [] }
        let prefix = parent.name + "::"
        return allDecks.filter { deck in
            guard deck.name.hasPrefix(prefix) else { return false }
            let remainder = deck.name.dropFirst(prefix.count)
            return !remainder.contains("::")
        }
    }

    private var deckFilterBar: some View {
        VStack(spacing: 0) {
            // Top-level deck chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chipButton(label: "All", isSelected: activeDeck == nil) {
                        parentDeck = nil
                        activeDeck = nil
                    }
                    ForEach(topLevelDecks) { deck in
                        chipButton(
                            label: deck.name,
                            isSelected: parentDeck?.id == deck.id && activeDeck?.id == deck.id
                        ) {
                            parentDeck = deck
                            activeDeck = deck
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Subdeck row — stays visible as long as a parent with children is selected
            if !childDecks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "All" chip = parent deck (includes subdecks)
                        chipButton(
                            label: "All",
                            isSelected: activeDeck?.id == parentDeck?.id,
                            small: true
                        ) {
                            activeDeck = parentDeck
                        }
                        ForEach(childDecks) { child in
                            chipButton(
                                label: shortName(child.name),
                                isSelected: activeDeck?.id == child.id,
                                small: true
                            ) {
                                activeDeck = child
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(.bar)
    }

    private func chipButton(
        label: String,
        isSelected: Bool,
        small: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(small ? .caption : .subheadline)
                .padding(.horizontal, small ? 10 : 12)
                .padding(.vertical, small ? 4 : 6)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemFill))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func shortName(_ fullName: String) -> String {
        String(fullName.split(separator: "::").last ?? Substring(fullName))
    }

    // MARK: - Data Loading

    private func loadDecks() async {
        do {
            allDecks = try deckClient.fetchAll()
        } catch {
            allDecks = []
        }
    }

    private func performSearch() async {
        isLoading = true
        let query = buildQuery()
        do {
            let results = try noteClient.search(query, nil)
            allNotes = results
            notes = Array(results.prefix(pageSize))
            hasMorePages = results.count > pageSize
        } catch {
            allNotes = []
            notes = []
            hasMorePages = false
        }
        isLoading = false
    }

    private func collectCardIDs(for noteIDs: Set<Int64>) -> [Int64] {
        var result: [Int64] = []
        for nid in noteIDs {
            if let cards = try? cardClient.fetchByNote(nid) {
                result.append(contentsOf: cards.map(\.id))
            }
        }
        return result
    }

    private func suspendSelected() {
        let ids = selectionState.selectedNoteIDs
        Task {
            let cardIDs = collectCardIDs(for: ids)
            for id in cardIDs {
                try? cardClient.suspend(id)
            }
            await MainActor.run {
                selectionState.exitSelectMode()
            }
            await performSearch()
        }
    }

    private func flagSelected(_ value: UInt32) {
        let ids = selectionState.selectedNoteIDs
        Task {
            let cardIDs = collectCardIDs(for: ids)
            for id in cardIDs {
                try? cardClient.flag(id, value)
            }
            await MainActor.run {
                selectionState.exitSelectMode()
            }
            await performSearch()
        }
    }

    private func deleteSelected() {
        let ids = selectionState.selectedNoteIDs
        Task {
            for id in ids {
                try? noteClient.delete(id)
            }
            await MainActor.run {
                selectionState.exitSelectMode()
            }
            await performSearch()
        }
    }

    private func loadNextPage() async {
        guard hasMorePages, !isLoading else { return }
        let loaded = notes.count
        let nextBatch = Array(allNotes.dropFirst(loaded).prefix(pageSize))
        notes.append(contentsOf: nextBatch)
        hasMorePages = notes.count < allNotes.count
    }

    /// Lazy-fetch full note details for a stub and update the arrays in place.
    private func fetchNoteDetails(id: Int64) async {
        guard let fullNote = try? noteClient.fetch(id) else { return }
        if let idx = notes.firstIndex(where: { $0.id == id }) {
            notes[idx] = fullNote
        }
        if let idx = allNotes.firstIndex(where: { $0.id == id }) {
            allNotes[idx] = fullNote
        }
    }

    private func buildQuery() -> String {
        var parts: [String] = []
        if let deck = activeDeck {
            parts.append("deck:\"\(deck.name)\"")
        }
        if let tag = activeTag {
            parts.append("tag:\"\(tag)\"")
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            parts.append(trimmed)
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - NoteContextMenuButton

/// Resolves the first cardId for a note lazily on first appear, then shows CardContextMenu.
@MainActor
struct NoteContextMenuButton: View {
    let noteId: Int64
    var onSuccess: (() -> Void)?

    @Dependency(\.cardClient) var cardClient
    @State private var firstCardId: Int64?

    var body: some View {
        Group {
            if let cardId = firstCardId {
                CardContextMenu(
                    cardId: cardId,
                    noteId: noteId,
                    onSuccess: onSuccess
                )
            } else {
                Image(systemName: "ellipsis.circle")
                    .font(AmgiFont.bodyEmphasis.font)
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: noteId) {
            guard firstCardId == nil else { return }
            firstCardId = (try? cardClient.fetchByNote(noteId))?.first?.id
        }
    }
}

// MARK: - NoteRowView

struct NoteRowView: View {
    let note: NoteRecord
    let notetypeName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.sfld)
                .font(.body)
                .lineLimit(1)
            if let subtitle = composeNoteSubtitle(notetypeName: notetypeName, tags: note.tags) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, 2)
    }
}
