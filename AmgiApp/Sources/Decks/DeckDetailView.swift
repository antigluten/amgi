import SwiftUI
import UIKit
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

    // Deck creation / note creation entry points
    @State private var showAddNote = false
    @State private var showCreateSubdeck = false
    @State private var newSubdeckName = ""
    @State private var subdeckCreationError: String?

    // Export
    @State private var exportInProgress = false
    @State private var exportedFile: ExportedFile?
    @State private var exportError: String?

    // Deck options (per-deck study config)
    @State private var showDeckOptions = false

    // Deck-context import
    @State private var showImporter = false
    @State private var importInProgress = false
    @State private var importMessage: String?
    @State private var importIsError = false

    private struct ExportedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddNote = true
                    } label: {
                        Label("Add Note", systemImage: "square.and.pencil")
                    }
                    if !deck.isFiltered {
                        Button {
                            newSubdeckName = ""
                            subdeckCreationError = nil
                            showCreateSubdeck = true
                        } label: {
                            Label("Create Subdeck", systemImage: "folder.badge.plus")
                        }
                    }
                    if !deck.isFiltered {
                        Button {
                            showDeckOptions = true
                        } label: {
                            Label("Deck Options…", systemImage: "slider.horizontal.3")
                        }
                    }
                    Divider()
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import .apkg…", systemImage: "square.and.arrow.down")
                    }
                    .disabled(importInProgress)
                    Button {
                        Task { await exportDeck() }
                    } label: {
                        Label("Export Deck…", systemImage: "square.and.arrow.up")
                    }
                    .disabled(exportInProgress)
                } label: {
                    Image(systemName: "plus")
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
        .sheet(item: $exportedFile) { file in
            DeckExportShareSheet(url: file.url) {
                exportedFile = nil
            }
        }
        .alert(
            "Export failed",
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            ),
            presenting: exportError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .sheet(isPresented: $showAddNote) {
            AddNoteView(preselectedDeckId: deck.id) {
                Task {
                    await loadCounts()
                    await loadChildren()
                }
            }
        }
        .sheet(isPresented: $showDeckOptions) {
            NavigationStack {
                DeckConfigView(deckId: deck.id, deckName: deck.name) {
                    showDeckOptions = false
                    Task { await loadCounts() }
                }
            }
        }
        .modifier(DeckImportPresentation(
            showImporter: $showImporter,
            importMessage: $importMessage,
            importIsError: $importIsError,
            importInProgress: importInProgress,
            onResult: handleImport
        ))
        .alert("Create Subdeck", isPresented: $showCreateSubdeck) {
            TextField("Subdeck name", text: $newSubdeckName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
            Button("Create") {
                Task { await createSubdeck() }
            }
            .disabled(newSubdeckName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {
                newSubdeckName = ""
            }
        } message: {
            if let err = subdeckCreationError {
                Text(err)
            } else {
                Text("Will be created as \(deck.name)::<name>")
            }
        }
        .task {
            await loadCounts()
            await loadChildren()
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let ext = url.pathExtension.lowercased()
            guard ext == "apkg" || ext == "colpkg" else {
                importIsError = true
                importMessage = "Unsupported file type. Please select an .apkg or .colpkg file."
                return
            }
            Task { await runImport(from: url) }
        case .failure(let error):
            importIsError = true
            importMessage = "Could not select file: \(error.localizedDescription)"
        }
    }

    private func runImport(from url: URL) async {
        importInProgress = true
        defer { importInProgress = false }
        do {
            // ImportHelper handles security-scoped access + temp-file copy;
            // run on a detached task so the file copy + Rust import don't
            // block the navigation stack.
            let summary = try await Task.detached {
                try ImportHelper.importPackage(from: url)
            }.value
            importIsError = false
            importMessage = summary
            await loadCounts()
            await loadChildren()
        } catch {
            importIsError = true
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func exportDeck() async {
        exportInProgress = true
        defer { exportInProgress = false }
        do {
            let url = try await Task.detached {
                try ImportHelper.exportDeck(deckId: deck.id, deckName: deck.name)
            }.value
            exportedFile = ExportedFile(url: url)
        } catch {
            exportError = "Failed to export deck: \(error.localizedDescription)"
        }
    }

    private func createSubdeck() async {
        let trimmed = newSubdeckName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Anki uses :: as the deck-hierarchy separator. Strip any user-supplied
        // separator collisions to avoid creating multi-level decks unexpectedly.
        let leafName = trimmed.replacingOccurrences(of: "::", with: "_")
        let fullName = "\(deck.name)::\(leafName)"
        do {
            _ = try deckClient.create(fullName)
            newSubdeckName = ""
            subdeckCreationError = nil
            await loadChildren()
        } catch {
            subdeckCreationError = "Failed to create subdeck: \(error.localizedDescription)"
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

/// File-importer + status presentation extracted from DeckDetailView's body
/// so the SwiftUI type checker doesn't blow up on the long modifier chain.
private struct DeckImportPresentation: ViewModifier {
    @Binding var showImporter: Bool
    @Binding var importMessage: String?
    @Binding var importIsError: Bool
    let importInProgress: Bool
    let onResult: (Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $showImporter,
                // .apkg/.colpkg are zip archives without registered UTTypes
                // on most installs; .data accepts any file and we re-check
                // the extension before handing the URL to the backend.
                allowedContentTypes: [.data]
            ) { result in
                onResult(result)
            }
            .alert(
                importIsError ? "Import failed" : "Import",
                isPresented: Binding(
                    get: { importMessage != nil },
                    set: { if !$0 { importMessage = nil } }
                ),
                presenting: importMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { Text($0) }
            .overlay(alignment: .top) {
                if importInProgress {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Importing…").font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                }
            }
    }
}

/// Wraps `UIActivityViewController` so the deck export `.apkg` can be shared
/// (AirDrop, Files, Mail, etc.). Dismisses via `onDismiss` when the activity
/// view completes or is cancelled.
private struct DeckExportShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onDismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
