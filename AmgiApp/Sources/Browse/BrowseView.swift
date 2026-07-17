import SwiftUI
import AnkiKit
import AnkiClients
import Dependencies
import AmgiTheme

enum BrowseSortOrder: String, CaseIterable, Sendable {
    case dateDesc = "Date (newest)"
    case titleAsc = "Title (A→Z)"
    case templateAsc = "Type (A→Z)"
}

/// Browse container: owns navigation, sheets, selection, and the toolbar,
/// and drives a `BrowseModel` for load/search/paging + note mutations.
/// Rendering is delegated to `BrowseContent`; the model owns all I/O so the
/// View is thin presentation wiring with no direct engine access.
struct BrowseView: View {
    @State private var model: BrowseModel
    @State private var selectionState = BrowseSelectionState()
    @State private var showAddNote = false
    @State private var showAddImageOcclusion = false
    @State private var showTagSheet = false
    @State private var showDeleteConfirm = false
    @State private var pendingSwipeDelete: NoteRecord?

    init(model: BrowseModel = BrowseModel()) {
        _model = State(initialValue: model)
    }

    // The body is split into small layered computed views: a single chained
    // expression here blows past the Swift type-checker's time budget, so each
    // layer applies only a few modifiers.
    var body: some View {
        @Bindable var model = model
        decoratedContent
            .searchable(text: $model.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search notes...")
            .onChange(of: model.searchText) { Task { await model.performSearch() } }
            .onChange(of: model.activeDeck) { Task { await model.performSearch() } }
            .onChange(of: model.activeTag) { Task { await model.performSearch() } }
            .task { await model.loadInitial() }
    }

    private var decoratedContent: some View {
        dialogContent
            .navigationTitle("Browse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
    }

    private var dialogContent: some View {
        sheetContent
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
                        await model.delete(note.id)
                        pendingSwipeDelete = nil
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
    }

    private var sheetContent: some View {
        BrowseContent(
            model: model,
            selectionState: $selectionState,
            onSwipeDelete: { pendingSwipeDelete = $0 }
        )
        .sheet(isPresented: $showAddNote) {
            AddNoteView {
                Task { await model.performSearch() }
            }
        }
        .sheet(isPresented: $showAddImageOcclusion) {
            AddImageOcclusionNoteView { Task { await model.performSearch() } }
        }
        .sheet(isPresented: $showTagSheet) {
            BatchTagSheet(noteIDs: selectionState.selectedNoteIDs) {
                Task {
                    selectionState.exitSelectMode()
                    await model.performSearch()
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
                        model.sortOrder = order
                    } label: {
                        if model.sortOrder == order {
                            Label(order.rawValue, systemImage: "checkmark")
                        } else {
                            Text(order.rawValue)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .disabled(model.notes.isEmpty)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if selectionState.isSelectMode {
                Button("Done") {
                    selectionState.exitSelectMode()
                }
            } else if !model.notes.isEmpty {
                Button("Edit") {
                    selectionState.enterSelectMode()
                }
            }
        }
        if selectionState.isSelectMode {
            selectionToolbar
        }
    }

    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Button {
                suspendSelected()
            } label: {
                Label("Suspend", systemImage: "pause.circle")
            }
            .disabled(selectionState.isEmpty)
        }
        ToolbarItem(placement: .bottomBar) { Spacer() }
        ToolbarItem(placement: .bottomBar) {
            Menu {
                Button { applyFlag(1) } label: { Label("Red flag",       systemImage: "flag.fill") }
                Button { applyFlag(2) } label: { Label("Orange flag",    systemImage: "flag.fill") }
                Button { applyFlag(3) } label: { Label("Green flag",     systemImage: "flag.fill") }
                Button { applyFlag(4) } label: { Label("Blue flag",      systemImage: "flag.fill") }
                Button { applyFlag(5) } label: { Label("Pink flag",      systemImage: "flag.fill") }
                Button { applyFlag(6) } label: { Label("Turquoise flag", systemImage: "flag.fill") }
                Button { applyFlag(7) } label: { Label("Purple flag",    systemImage: "flag.fill") }
                Divider()
                Button { applyFlag(0) } label: { Label("Clear flag",     systemImage: "flag.slash") }
            } label: {
                Label("Flag", systemImage: "flag")
            }
            .disabled(selectionState.isEmpty)
        }
        ToolbarItem(placement: .bottomBar) { Spacer() }
        ToolbarItem(placement: .bottomBar) {
            Button {
                showTagSheet = true
            } label: {
                Label("Tags", systemImage: "tag")
            }
            .disabled(selectionState.isEmpty)
        }
        ToolbarItem(placement: .bottomBar) { Spacer() }
        ToolbarItem(placement: .bottomBar) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(selectionState.isEmpty)
        }
    }

    // MARK: - Selection actions

    /// Capture the current selection, drop out of select mode for snappy
    /// feedback, then run the batch mutation on the model.
    private func suspendSelected() {
        let ids = selectionState.selectedNoteIDs
        selectionState.exitSelectMode()
        Task { await model.suspendSelected(ids) }
    }

    private func applyFlag(_ value: UInt32) {
        let ids = selectionState.selectedNoteIDs
        selectionState.exitSelectMode()
        Task { await model.flagSelected(ids, value: value) }
    }

    private func deleteSelected() {
        let ids = selectionState.selectedNoteIDs
        selectionState.exitSelectMode()
        Task { await model.deleteSelected(ids) }
    }
}

// MARK: - BrowseContent

/// Pure rendering for the Browse screen: the note list (with select-mode,
/// swipe-to-delete, and paging hooks) plus the deck/tag filter bar. Reads
/// state from the model and drives mutations through it, but owns no I/O of
/// its own — so it renders in a `#Preview` from a seeded model.
struct BrowseContent: View {
    @Environment(\.palette) private var palette
    @Bindable var model: BrowseModel
    @Binding var selectionState: BrowseSelectionState
    let onSwipeDelete: (NoteRecord) -> Void

    var body: some View {
        statefulContent
            .safeAreaInset(edge: .top) {
                if !model.allDecks.isEmpty || !model.allTags.isEmpty {
                    filterBar
                }
            }
    }

    @ViewBuilder
    private var statefulContent: some View {
        if model.notes.isEmpty && !model.isLoading && model.searchText.isEmpty && model.activeDeck == nil {
            ContentUnavailableView(
                "Browse Notes",
                systemImage: "magnifyingglass",
                description: Text("Search by content, tags, or filter by deck.")
            )
        } else if model.notes.isEmpty && !model.isLoading {
            ContentUnavailableView.search(text: model.searchText)
        } else {
            noteList
        }
    }

    // MARK: - Note List

    private var noteList: some View {
        List {
            ForEach(model.sortedNotes, id: \.id) { note in
                noteRow(note)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            onSwipeDelete(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }

            if model.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .navigationDestination(for: NoteRecord.self) { note in
            // If tapped a stub, fetch full details first.
            NoteEditingDestinationView(note: model.resolved(note)) {
                Task { await model.performSearch() }
            }
        }
    }

    @ViewBuilder
    private func noteRow(_ note: NoteRecord) -> some View {
        HStack {
            if selectionState.isSelectMode {
                Image(systemName: selectionState.contains(note.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectionState.contains(note.id) ? palette.accent : palette.textSecondary)
                NoteRowView(note: note, notetypeName: model.notetypeNames[note.mid])
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectionState.toggle(note.id)
                    }
                    .onAppear { onRowAppear(note) }
            } else {
                HStack {
                    NavigationLink(value: note) {
                        NoteRowView(note: note, notetypeName: model.notetypeNames[note.mid])
                            .onAppear { onRowAppear(note) }
                    }
                    NoteContextMenuButton(noteId: note.id) {
                        Task { await model.performSearch() }
                    }
                }
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.5) {
                    selectionState.enterSelectMode(preselect: note.id)
                }
            }
        }
    }

    /// Lazy-load stub notes when they scroll on screen, and page in the next
    /// batch as the last row appears.
    private func onRowAppear(_ note: NoteRecord) {
        if note.sfld == "Loading..." {
            Task { await model.fetchNoteDetails(id: note.id) }
        }
        if note.id == model.notes.last?.id {
            Task { await model.loadNextPage() }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 0) {
            if !model.allDecks.isEmpty {
                deckFilterBar
            }
            if !model.allTags.isEmpty {
                tagChipRow
            }
        }
    }

    private var tagChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "All", isSelected: model.activeTag == nil) {
                    model.activeTag = nil
                }
                ForEach(model.allTags, id: \.self) { tag in
                    chipButton(label: tag, isSelected: model.activeTag == tag) {
                        model.activeTag = (model.activeTag == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var deckFilterBar: some View {
        VStack(spacing: 0) {
            // Top-level deck chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chipButton(label: "All", isSelected: model.activeDeck == nil) {
                        model.parentDeck = nil
                        model.activeDeck = nil
                    }
                    ForEach(model.topLevelDecks) { deck in
                        chipButton(
                            label: deck.name,
                            isSelected: model.parentDeck?.id == deck.id && model.activeDeck?.id == deck.id
                        ) {
                            model.parentDeck = deck
                            model.activeDeck = deck
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Subdeck row — stays visible as long as a parent with children is selected
            if !model.childDecks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "All" chip = parent deck (includes subdecks)
                        chipButton(
                            label: "All",
                            isSelected: model.activeDeck?.id == model.parentDeck?.id,
                            small: true
                        ) {
                            model.activeDeck = model.parentDeck
                        }
                        ForEach(model.childDecks) { child in
                            chipButton(
                                label: shortName(child.name),
                                isSelected: model.activeDeck?.id == child.id,
                                small: true
                            ) {
                                model.activeDeck = child
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
}

private extension BrowseContent {
    func chipButton(
        label: String,
        isSelected: Bool,
        small: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .amgiFont(small ? .caption : .body)
                .padding(.horizontal, small ? 10 : 12)
                .padding(.vertical, small ? 4 : 6)
                .background(isSelected ? palette.accent : palette.surface)
                .foregroundStyle(isSelected ? .white : palette.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    func shortName(_ fullName: String) -> String {
        String(fullName.split(separator: "::").last ?? Substring(fullName))
    }
}

// MARK: - NoteContextMenuButton

/// Resolves the first cardId for a note lazily on first appear, then shows CardContextMenu.
@MainActor
struct NoteContextMenuButton: View {
    let noteId: NoteID
    var onSuccess: (() -> Void)?

    @Dependency(\.cardClient) var cardClient
    @State private var firstCardId: CardID?

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
                    .amgiFont(.bodyEmphasis)
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: noteId) {
            guard firstCardId == nil else { return }
            firstCardId = (try? await cardClient.fetchByNote(noteId))?.first?.id
        }
    }
}

// MARK: - NoteRowView

struct NoteRowView: View {
    @Environment(\.palette) private var palette
    let note: NoteRecord
    let notetypeName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.sfld)
                .font(.body)
                .lineLimit(1)
            if let subtitle = composeNoteSubtitle(notetypeName: notetypeName, tags: note.tags) {
                Text(subtitle)
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    // Seed the model directly: BrowseContent has no `.task`, so the sample
    // notes aren't overwritten by a load, and no live backend is touched.
    let model = BrowseModel()
    model.notes = [
        NoteRecord(id: NoteID(1), guid: "g1", mid: NotetypeID(1), mod: 1_700_000_300,
                   tags: "vocab", flds: "", sfld: "안녕하세요 — hello", csum: 0),
        NoteRecord(id: NoteID(2), guid: "g2", mid: NotetypeID(1), mod: 1_700_000_200,
                   tags: "marked grammar", flds: "", sfld: "Bonjour le monde", csum: 0),
        NoteRecord(id: NoteID(3), guid: "g3", mid: NotetypeID(2), mod: 1_700_000_100,
                   flds: "", sfld: "The quick brown fox jumps over the lazy dog", csum: 0),
    ]
    model.allNotes = model.notes
    model.hasMorePages = false
    model.notetypeNames = [NotetypeID(1): "Basic", NotetypeID(2): "Cloze"]
    model.allTags = ["vocab", "grammar", "marked"]
    return NavigationStack {
        BrowseContent(
            model: model,
            selectionState: .constant(BrowseSelectionState()),
            onSwipeDelete: { _ in }
        )
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
