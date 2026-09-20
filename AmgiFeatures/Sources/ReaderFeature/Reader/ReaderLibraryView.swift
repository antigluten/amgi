//
//  ReaderLibraryView.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 05.05.2026.
//

import Reader
import AppCore
import Sharing
package import SwiftUI
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
package struct ReaderLibraryView: View {
    /// Bumped by the host after sync / import / review so the shelf reloads.
    /// Keyed into `.task` rather than applied as an `.id` — an `.id` change
    /// discards the whole subtree, throwing away the search text and scroll
    /// position to achieve a reload the task already does.
    private let refreshID: UUID?

    @State private var model: ReaderLibraryModel

    @Shared(.appStorage(ReaderPreferenceKey.deckName)) private var deckName: String = ""
    @Shared(.appStorage(ReaderPreferences.Keys.bookshelfSortMode))
    private var sortModeRaw: String = BookshelfSortMode.recent.rawValue

    @State private var searchText: String = ""
    @State private var isImporting: Bool = false
    @State private var showConfiguration: Bool = false
    @FocusState private var searchFocused: Bool

    package init(refreshID: UUID? = nil) {
        self.refreshID = refreshID
        _model = State(initialValue: ReaderLibraryModel())
    }

    /// Preview / test seam — lets a caller inside the module inject a
    /// pre-populated model. Deliberately not public.
    init(model: ReaderLibraryModel) {
        self.refreshID = nil
        _model = State(initialValue: model)
    }

    private var sortMode: BookshelfSortMode {
        BookshelfSortMode(rawValue: sortModeRaw) ?? .recent
    }

    private var sortSelection: Binding<BookshelfSortMode> {
        Binding(
            get: { sortMode },
            set: { mode in $sortModeRaw.withLock { $0 = mode.rawValue } }
        )
    }

    package var body: some View {
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
        .toolbar { toolbarContent }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search books"
        )
        .searchFocused($searchFocused)
        .onChange(of: searchText) { _, _ in model.rebuildViewData(searchText: searchText, sortMode: sortMode) }
        .onChange(of: sortModeRaw) { _, _ in model.rebuildViewData(searchText: searchText, sortMode: sortMode) }
        .onChange(of: deckName) { _, _ in model.startReload(searchText: searchText, sortMode: sortMode) }
        .refreshable { await model.reload(searchText: searchText, sortMode: sortMode) }
        .task(id: refreshID) { model.startReload(searchText: searchText, sortMode: sortMode) }
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Import EPUB…", systemImage: "square.and.arrow.down") {
                isImporting = true
            }
            .keyboardShortcut("o", modifiers: .command)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort By", selection: sortSelection) {
                    ForEach(BookshelfSortMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                Divider()
                Button("Find", systemImage: "magnifyingglass") {
                    searchFocused = true
                }
                .keyboardShortcut("f", modifiers: .command)
                Button("Reader Settings", systemImage: "slider.horizontal.3") {
                    showConfiguration = true
                }
            } label: {
                Label("More", systemImage: "ellipsis")
            }
        }
    }

    private func handleImport(result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            Task { await model.importEPUBs(urls, searchText: searchText, sortMode: sortMode) }
        case .failure(let error):
            model.importError = error.localizedDescription
        }
    }
}
