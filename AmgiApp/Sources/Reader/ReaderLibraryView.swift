import AmgiReader
import Sharing
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sort mode

enum BookshelfSortMode: String, CaseIterable, Identifiable {
    case recent
    case title
    case progress

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recent:   "Recently Read"
        case .title:    "Title"
        case .progress: "Progress"
        }
    }
}

// MARK: - Library view

/// Library container: owns navigation, search, sheets, and the toolbar, and
/// drives a `ReaderLibraryModel` for load/import. Rendering is delegated to
/// `ReaderLibraryContent`; the model owns all I/O so the View is thin
/// presentation wiring with no direct engine access.
struct ReaderLibraryView: View {
    @State private var model: ReaderLibraryModel

    @Shared(.appStorage(ReaderPreferenceKey.deckName)) private var deckName: String = ""
    @Shared(.appStorage(ReaderPreferences.Keys.bookshelfSortMode))
    private var sortModeRaw: String = BookshelfSortMode.recent.rawValue

    @State private var searchText: String = ""
    @State private var isImporting: Bool = false
    @State private var showConfiguration: Bool = false

    init(model: ReaderLibraryModel = ReaderLibraryModel()) {
        _model = State(initialValue: model)
    }

    private var sortMode: BookshelfSortMode {
        BookshelfSortMode(rawValue: sortModeRaw) ?? .recent
    }

    var body: some View {
        ReaderLibraryContent(
            state: model.state,
            bookForId: { model.book(for: $0) },
            progress: model.progress,
            onImport: { isImporting = true },
            onConfigure: { showConfiguration = true },
            onRetry: { model.startReload(searchText: searchText, sortMode: sortMode) }
        )
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu { plusMenu } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Library actions")
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search books"
        )
        .onChange(of: searchText) { _, _ in model.rebuildViewData(searchText: searchText, sortMode: sortMode) }
        .onChange(of: sortModeRaw) { _, _ in model.rebuildViewData(searchText: searchText, sortMode: sortMode) }
        .onChange(of: deckName) { _, _ in model.startReload(searchText: searchText, sortMode: sortMode) }
        .refreshable { await model.reload(searchText: searchText, sortMode: sortMode) }
        .task { model.startReload(searchText: searchText, sortMode: sortMode) }
        .sheet(isPresented: $showConfiguration) {
            NavigationStack {
                ReaderConfigurationView {
                    showConfiguration = false
                    model.startReload(searchText: searchText, sortMode: sortMode)
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result: result)
        }
        .alert("Import failed", isPresented: Binding(
            get: { model.importError != nil },
            set: { if !$0 { model.importError = nil } }
        )) {
            Button("OK") { model.importError = nil }
        } message: {
            Text(model.importError ?? "")
        }
    }

    @ViewBuilder
    private var plusMenu: some View {
        Button { isImporting = true } label: {
            Label("Import EPUB…", systemImage: "square.and.arrow.down")
        }
        Divider()
        Menu("Sort by") {
            ForEach(BookshelfSortMode.allCases) { mode in
                Button {
                    $sortModeRaw.withLock { $0 = mode.rawValue }
                } label: {
                    if sortMode == mode {
                        Label(mode.label, systemImage: "checkmark")
                    } else {
                        Text(mode.label)
                    }
                }
            }
        }
        Divider()
        Button { showConfiguration = true } label: {
            Label("Settings", systemImage: "slider.horizontal.3")
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { await model.importEPUBs(urls, searchText: searchText, sortMode: sortMode) }
        case .failure(let error):
            model.importError = error.localizedDescription
        }
    }
}
