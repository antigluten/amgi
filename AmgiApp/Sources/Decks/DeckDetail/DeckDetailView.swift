import SwiftUI
import AmgiTheme
import AmgiUI
import AnkiKit
import AnkiClients
import Dependencies

/// Owns the `DeckDetailModel` (data state) and a single `Destination?`
/// that drives every modal axis: full-screen review, sheets, alerts,
/// and the file importer.
///
/// Presentation is delegated to `AmgiUI.DeckDetailScreen` — this file
/// is a thin assembler that builds a `DeckDetailViewData` DTO from the
/// model and dispatches `DeckDetailScreen.Action` callbacks.
struct DeckDetailView: View {
    let deck: DeckInfo

    @Environment(\.palette) private var palette
    @State private var model: DeckDetailModel
    @State private var destination: DeckDetailDestination?
    @State private var newSubdeckName = ""
    @State private var pendingSubdeck: DeckInfo?

    init(deck: DeckInfo) {
        self.deck = deck
        _model = State(initialValue: DeckDetailModel(deck: deck))
    }

    private var shortTitle: String {
        String(deck.name.split(separator: "::", omittingEmptySubsequences: true).last ?? Substring(deck.name))
    }

    private var currentAlert: DeckDetailAlert? {
        if case .alert(let a) = destination { return a }
        return nil
    }

    private var alertTitle: String {
        guard let alert = currentAlert else { return "" }
        switch alert {
        case .empty: return "Empty \"\(shortTitle)\"?"
        case .error: return "Something went wrong"
        case .info: return "Done"
        case .subdeck: return "Create Subdeck"
        }
    }

    private var viewState: DeckDetailViewState {
        guard model.hasLoaded else { return .loading }
        let isEmpty = model.counts.total == 0 && model.childDecks.isEmpty
        let subtitle: String = {
            if let snap = model.statsSnapshot, !snap.subtitle.isEmpty { return snap.subtitle }
            return isEmpty
                ? "No cards yet · Add some to start studying"
                : "Tap Study to start a session"
        }()
        let insights = model.statsSnapshot?.insights ?? .empty
        return .loaded(DeckDetailViewData(
            title: shortTitle,
            subtitle: subtitle,
            tone: DeckTonePalette.tone(for: deck.name),
            glyph: DeckGlyph.from(name: deck.name),
            tileCounts: DeckDetailTileData(
                newCount: model.counts.newCount,
                learnCount: model.counts.learnCount,
                reviewCount: model.counts.reviewCount
            ),
            isFiltered: deck.isFiltered,
            isEmpty: isEmpty,
            subdecks: model.childDecks.map(Self.subdeckRow(from:)),
            insights: insights,
            isActionInFlight: model.actionInFlight
        ))
    }

    var body: some View {
        contentWithToolbar
            .modifier(SheetCoverModifier(
                destination: $destination,
                deckId: deck.id,
                onReviewDismiss: {
                    destination = nil
                    Task {
                        await model.loadCounts()
                        model.loadStats()
                    }
                },
                sheetContent: { sheet in AnyView(sheetContent(for: sheet)) }
            ))
            .modifier(AlertImporterModifier(
                destination: $destination,
                currentAlert: currentAlert,
                alertTitle: alertTitle,
                alertActions: { AnyView(alertActions(for: $0)) },
                alertMessage: { AnyView(alertMessage(for: $0)) },
                onImportResult: { result in Task { await runImport(result) } }
            ))
            .overlay(alignment: .top) { ImportInProgressBanner(visible: model.importInProgress) }
            .overlay(alignment: .bottom) { RebuildFeedbackBanner(feedback: model.rebuildFeedback) }
            .animation(.easeInOut(duration: 0.2), value: model.rebuildFeedback)
            .animation(.easeInOut(duration: 0.2), value: model.importInProgress)
            .task {
                await model.loadCounts()
                await model.loadChildren()
                model.loadStats()
            }
    }

    private var contentWithToolbar: some View {
        DeckDetailScreen(
            state: viewState,
            heatmapSlot: { EmptyView() }, // R03 will inject its chart here.
            onAction: handle
        )
        .navigationTitle(shortTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .navigationDestination(item: $pendingSubdeck) { sub in
            DeckDetailView(deck: sub)
        }
    }

    // MARK: - Action dispatch

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    destination = .sheet(.addNote)
                } label: {
                    Label("Add Note", systemImage: "square.and.pencil")
                }
                if !deck.isFiltered {
                    Button {
                        newSubdeckName = ""
                        destination = .alert(.subdeck)
                    } label: {
                        Label("Create Subdeck", systemImage: "folder.badge.plus")
                    }
                    Button {
                        destination = .sheet(.showDeckOptions)
                    } label: {
                        Label("Deck Options…", systemImage: "slider.horizontal.3")
                    }
                }
                Divider()
                Button {
                    destination = .importer
                } label: {
                    Label("Import .apkg…", systemImage: "square.and.arrow.down")
                }
                .disabled(model.importInProgress)
                Button {
                    Task { await runExport() }
                } label: {
                    Label("Export Deck…", systemImage: "square.and.arrow.up")
                }
                .disabled(model.exportInProgress)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("More")
        }
    }
}

private extension DeckDetailView {
    func handle(_ action: DeckDetailScreen<EmptyView>.Action) {
        switch action {
        case .studyNow:
            destination = .review
        case .rebuild:
            Task { await runRebuild() }
        case .emptyDeck:
            destination = .alert(.empty)
        case .subdeckSelected(let row):
            // Push by setting pendingSubdeck — navigationDestination(item:)
            // below picks it up and pushes onto the parent stack. We use
            // an item-bound push rather than the parent's value-bound
            // navigationDestination(for: DeckInfo.self) so this Container
            // owns the dismissal contract for the row tap.
            pendingSubdeck = DeckInfo(
                id: DeckID(row.id),
                name: row.fullName,
                counts: DeckCounts(
                    newCount: row.newCount,
                    learnCount: row.learnCount,
                    reviewCount: row.reviewCount
                ),
                isFiltered: row.isFiltered
            )
        }
    }

    @ViewBuilder
    func sheetContent(for sheet: DeckDetailSheet) -> some View {
        switch sheet {
        case .addNote:
            AddNoteView(preselectedDeckId: deck.id) {
                Task {
                    await model.loadCounts()
                    await model.loadChildren()
                    model.loadStats()
                }
            }
        case .showDeckOptions:
            NavigationStack {
                DeckConfigView(deckId: deck.id, deckName: deck.name) {
                    destination = nil
                    Task {
                        await model.loadCounts()
                        model.loadStats()
                    }
                }
            }
        case .exportFile(let url):
            DeckExportShareSheet(url: url) {
                destination = nil
            }
        }
    }

    @ViewBuilder
    func alertActions(for alert: DeckDetailAlert) -> some View {
        switch alert {
        case .empty:
            Button("Empty", role: .destructive) {
                Task { await runEmpty() }
            }
            Button("Cancel", role: .cancel) {}
        case .error, .info:
            Button("OK", role: .cancel) {}
        case .subdeck:
            TextField("Subdeck name", text: $newSubdeckName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
            Button("Create") {
                let name = newSubdeckName
                Task { await runCreateSubdeck(name: name) }
            }
            .disabled(newSubdeckName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {
                newSubdeckName = ""
            }
        }
    }

    @ViewBuilder
    func alertMessage(for alert: DeckDetailAlert) -> some View {
        switch alert {
        case .empty:
            Text("Cards will be returned to their home decks.")
        case .error(let msg), .info(let msg):
            Text(msg)
        case .subdeck:
            Text("Will be created as \(deck.name)::<name>")
        }
    }

    // MARK: Action bridges (model results → destination state)

    func runRebuild() async {
        if let err = await model.rebuild() {
            destination = .alert(.error(err))
        } else {
            model.loadStats()
        }
    }

    func runEmpty() async {
        if let err = await model.empty() {
            destination = .alert(.error(err))
        } else {
            model.loadStats()
        }
    }

    func runExport() async {
        switch await model.exportDeck() {
        case .success(let url):
            destination = .sheet(.exportFile(url))
        case .failure(let msg):
            destination = .alert(.error(msg))
        }
    }

    func runImport(_ result: Result<URL, Error>) async {
        switch await model.handleImport(result) {
        case .success(let summary):
            destination = .alert(.info(summary))
            model.loadStats()
        case .failure(let msg):
            destination = .alert(.error(msg))
        }
    }

    func runCreateSubdeck(name: String) async {
        if let err = await model.createSubdeck(rawName: name) {
            destination = .alert(.error(err))
        } else {
            newSubdeckName = ""
            destination = nil
        }
    }

    // MARK: - Mapping

    static func subdeckRow(from node: DeckTreeNode) -> DeckSubdeckRowData {
        DeckSubdeckRowData(
            id: node.id.rawValue,
            name: node.name,
            fullName: node.fullName,
            newCount: node.counts.newCount,
            learnCount: node.counts.learnCount,
            reviewCount: node.counts.reviewCount,
            isFiltered: node.isFiltered
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    // Construct the view inside `withDependencies` so the model captures the
    // preview clients at init; the seeded `.task` load then renders deterministically.
    withDependencies {
        $0.deckClient = .previewValue
        $0.statsClient = .previewValue
    } operation: {
        NavigationStack {
            DeckDetailView(deck: .sample)
        }
    }
}
#endif
