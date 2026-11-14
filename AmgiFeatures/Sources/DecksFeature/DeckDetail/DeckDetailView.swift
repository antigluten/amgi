//
//  DeckDetailView.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import SwiftUI
import AppShared
import Theme
import UI
import AnkiKit
import AnkiClients
import Dependencies
import BrowseFeature
import Foundation

struct DeckDetailView: View {
    let deck: DeckInfo

    @Environment(\.palette) private var palette
    @Dependency(\.collectionStore) private var store
    @State private var model: DeckDetailModel
    @State private var destination: DeckDetailDestination?
    @State private var newSubdeckName = ""
    @State private var limitDelta = ""
    @State private var pendingSubdeck: DeckInfo?

    init(deck: DeckInfo) {
        self.deck = deck
        _model = State(initialValue: DeckDetailModel(deck: deck))
    }

    private var shortTitle: String {
        Self.leafName(from: deck.name)
    }

    static func leafName(from fullName: String) -> String {
        String(fullName.split(separator: "::", omittingEmptySubsequences: true).last ?? Substring(fullName))
    }

    private var currentAlert: DeckDetailAlert? {
        if case .alert(let a) = destination { return a }
        return nil
    }

    private var alertTitle: String {
        guard let alert = currentAlert else { return "" }
        switch alert {
        case .empty: return String(localized: "Empty \"\(shortTitle)\"?", bundle: .module)
        case .error(let title, _): return title
        }
    }

    private var viewState: DeckDetailViewState {
        guard model.hasLoaded else { return .loading }
        let isEmpty = model.isEmpty
        let subtitle: String = {
            if let snap = model.statsSnapshot, !snap.subtitle.isEmpty { return snap.subtitle }
            return isEmpty
                ? String(localized: "No cards yet · Add some to start studying", bundle: .module)
                : String(localized: "Tap Study to start a session", bundle: .module)
        }()
        let insights = model.statsSnapshot?.insights ?? .empty
        return .loaded(DeckDetailViewData(
            title: shortTitle,
            subtitle: subtitle,
            tone: DeckTonePalette.tone(for: deck.name),
            deckName: shortTitle,
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
                    store.invalidateAll()
                },
                sheetContent: { sheet in AnyView(sheetContent(for: sheet)) }
            ))
            .modifier(AlertModifier(
                destination: $destination,
                currentAlert: currentAlert,
                alertTitle: alertTitle,
                alertActions: { AnyView(alertActions(for: $0)) },
                alertMessage: { AnyView(alertMessage(for: $0)) }
            ))
            .overlay(alignment: .bottom) {
                FeedbackToast(feedback: model.feedback) { model.feedback = nil }
            }
            .animation(AmgiMotion.momentum, value: model.feedback)
            .task(id: store.generation) {
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
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section {
                    Button {
                        destination = .sheet(.addNote)
                    } label: {
                        Label(String(localized: "Add Note…", bundle: .module), systemImage: "square.and.pencil")
                    }
                    if !deck.isFiltered {
                        Button {
                            newSubdeckName = ""
                            destination = .sheet(.createSubdeck)
                        } label: {
                            Label(String(localized: "Create Subdeck…", bundle: .module), systemImage: "folder.badge.plus")
                        }
                    }
                }
                if !deck.isFiltered {
                    Section {
                        Button {
                            destination = .sheet(.showDeckOptions)
                        } label: {
                            Label(String(localized: "Deck Options…", bundle: .module), systemImage: "slider.horizontal.3")
                        }
                        Button {
                            limitDelta = Self.defaultNewDelta
                            destination = .sheet(.extendLimit(.new))
                        } label: {
                            Label(String(localized: "Increase New Limit…", bundle: .module), systemImage: "plus.rectangle.on.rectangle")
                        }
                        Button {
                            limitDelta = Self.defaultReviewDelta
                            destination = .sheet(.extendLimit(.review))
                        } label: {
                            Label(String(localized: "Increase Review Limit…", bundle: .module), systemImage: "plus.rectangle.on.rectangle")
                        }
                    }
                }
                Section {
                    Button {
                        Task { await runExport() }
                    } label: {
                        Label(String(localized: "Export Deck…", bundle: .module), systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.exportInProgress)
                }
            } label: {
                Label(String(localized: "More", bundle: .module), systemImage: "ellipsis")
            }
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
            AddNoteView(preselectedDeckId: deck.id) {}
        case .showDeckOptions:
            NavigationStack {
                DeckConfigView(deckId: deck.id, deckName: deck.name) {
                    destination = nil
                    store.apply(CollectionChanges(deck: true, studyQueues: true))
                }
            }
        case .exportFile(let url):
            ShareSheet(items: [url]) {
                destination = nil
                try? FileManager.default.removeItem(at: url)
            }
        case .createSubdeck:
            TextPromptSheet(
                title: String(localized: "Create Subdeck", bundle: .module),
                placeholder: String(localized: "Subdeck name", bundle: .module),
                footer: String(localized: "Created inside \(shortTitle).", bundle: .module),
                confirmLabel: String(localized: "Create", bundle: .module),
                capitalization: .words,
                isValid: { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                onConfirm: { name in await model.createSubdeck(rawName: name) },
                text: $newSubdeckName
            )
        case .extendLimit(let kind):
            TextPromptSheet(
                title: kind.promptTitle,
                placeholder: String(localized: "Extra cards", bundle: .module),
                footer: kind.promptFooter,
                confirmLabel: String(localized: "Increase", bundle: .module),
                keyboard: .numberPad,
                isValid: { Self.parseDelta($0) != nil },
                onConfirm: { text in await runExtendLimit(kind, delta: text) },
                text: $limitDelta
            )
        }
    }

    @ViewBuilder
    func alertActions(for alert: DeckDetailAlert) -> some View {
        switch alert {
        case .empty:
            Button(String(localized: "Empty", bundle: .module), role: .destructive) {
                Task { await runEmpty() }
            }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        case .error:
            Button(String(localized: "OK", bundle: .module), role: .cancel) {}
        }
    }

    @ViewBuilder
    func alertMessage(for alert: DeckDetailAlert) -> some View {
        switch alert {
        case .empty:
            Text("Cards will be returned to their home decks.", bundle: .module)
        case .error(_, let message):
            Text(message)
        }
    }

    // MARK: Action bridges (model results → destination state)

    func runRebuild() async {
        if let err = await model.rebuild() {
            destination = .alert(.error(title: String(localized: "Couldn't rebuild \"\(shortTitle)\"", bundle: .module), message: err))
        }
    }

    func runEmpty() async {
        if let err = await model.empty() {
            destination = .alert(.error(title: String(localized: "Couldn't empty \"\(shortTitle)\"", bundle: .module), message: err))
        }
    }

    func runExport() async {
        switch await model.exportDeck() {
        case .success(let url):
            destination = .sheet(.exportFile(url))
        case .failure(let msg):
            destination = .alert(.error(title: String(localized: "Couldn't export \"\(shortTitle)\"", bundle: .module), message: msg))
        }
    }

    static let defaultNewDelta = "10"
    static let defaultReviewDelta = "50"

    static func parseDelta(_ text: String) -> Int32? {
        guard let value = Int32(text.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
        return value
    }

    func runExtendLimit(_ kind: DeckLimitKind, delta: String) async -> String? {
        guard let amount = Self.parseDelta(delta) else { return nil }
        return await model.extendLimit(kind, by: amount)
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
