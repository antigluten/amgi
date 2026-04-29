import SwiftUI
import AmgiTheme
import AnkiKit
import AnkiClients
import AnkiServices
import Dependencies

extension NoteRecord: Identifiable {}

struct EmptyCardsView: View {
    @Dependency(\.cardRenderingService) var cardRenderingService
    @Dependency(\.cardClient) var cardClient
    @Dependency(\.deckClient) var deckClient
    @Dependency(\.noteClient) var noteClient
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var isLoading = true
    @State private var report: String = ""
    @State private var noteEntries: [NoteEntry] = []
    @State private var isDeletingAll = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    @State private var editingNote: NoteRecord?

    struct NoteEntry: Identifiable {
        let id: Int64
        let cardIds: [Int64]
        let totalCards: Int
        let emptyCards: Int
        let deckName: String
        let willDeleteNote: Bool
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(palette.background)
                } else {
                    resultsList
                }
            }
            .navigationTitle("Empty Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .amgiToolbarTextButton()
                }
            }
            .alert("Delete empty cards?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteAllEmpty() }
                }
            } message: {
                let count = noteEntries.reduce(0) { $0 + $1.cardIds.count }
                Text("Delete \(count) empty cards? This cannot be undone.")
            }
            .alert("Done", isPresented: $showSuccess) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Empty cards deleted.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            .task { await loadEmptyCards() }
            .sheet(item: regularEditingNoteBinding) { note in
                NoteEditingDestinationView(note: note, embedInNavigationStack: true) {
                    Task { await loadEmptyCards() }
                }
            }
            .fullScreenCover(item: imageOcclusionEditingNoteBinding) { note in
                NoteEditingDestinationView(note: note, embedInNavigationStack: true) {
                    Task { await loadEmptyCards() }
                }
            }
        }
    }

    private var imageOcclusionEditingNoteBinding: Binding<NoteRecord?> {
        Binding(
            get: {
                guard let editingNote, editingNote.isImageOcclusionNote else { return nil }
                return editingNote
            },
            set: { newValue in
                if let newValue {
                    editingNote = newValue
                } else if editingNote?.isImageOcclusionNote == true {
                    editingNote = nil
                }
            }
        )
    }

    private var regularEditingNoteBinding: Binding<NoteRecord?> {
        Binding(
            get: {
                guard let editingNote, !editingNote.isImageOcclusionNote else { return nil }
                return editingNote
            },
            set: { newValue in
                if let newValue {
                    editingNote = newValue
                } else if editingNote?.isImageOcclusionNote != true {
                    editingNote = nil
                }
            }
        )
    }

    private var resultsList: some View {
        List {
            if noteEntries.isEmpty {
                Section {
                    Label("No empty cards found", systemImage: "checkmark.circle")
                        .amgiStatusText(.positive)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .listRowBackground(palette.surfaceElevated)
                }
            } else {
                Section {
                    let totalEmpty = noteEntries.reduce(0) { $0 + $1.cardIds.count }
                    Label(
                        "Found \(totalEmpty) notes with empty cards",
                        systemImage: "rectangle.stack.badge.minus"
                    )
                    .amgiStatusText(.warning)
                    .listRowBackground(palette.surfaceElevated)

                    if !report.isEmpty {
                        DisclosureGroup("Report") {
                            Text(report)
                                .amgiFont(.caption)
                                .foregroundStyle(palette.textSecondary)
                        }
                        .listRowBackground(palette.surfaceElevated)
                    }
                }

                Section("Affected notes") {
                    ForEach(noteEntries) { entry in
                        Button {
                            Task { await openNoteEditor(noteId: entry.id) }
                        } label: {
                            HStack(alignment: .top, spacing: AmgiSpacing.sm) {
                                VStack(alignment: .leading, spacing: AmgiSpacing.xxs) {
                                    Text("Note id: \(entry.id)")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(palette.textPrimary)
                                    Text("\(entry.emptyCards) of \(entry.totalCards) cards empty")
                                        .amgiFont(.caption)
                                        .foregroundStyle(palette.textSecondary)
                                    Text("Deck: \(entry.deckName)")
                                        .amgiFont(.caption)
                                        .foregroundStyle(palette.textSecondary)
                                    if entry.willDeleteNote {
                                        Text("Will also delete the note (all cards empty)")
                                            .amgiStatusText(.danger, font: .caption)
                                    }
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "square.and.pencil")
                                    .foregroundStyle(palette.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .listRowBackground(palette.surfaceElevated)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        if isDeletingAll {
                            HStack {
                                Text("Delete All Empty Cards")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Label("Delete All Empty Cards", systemImage: "trash")
                        }
                    }
                    .disabled(isDeletingAll)
                    .listRowBackground(palette.surfaceElevated)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
    }

    private func loadEmptyCards() async {
        let cardRenderingServiceCapture = cardRenderingService
        let capturedCardClient = cardClient
        let capturedDeckClient = deckClient
        do {
            let emptyReport: EmptyCardsReport = try await Task.detached {
                try cardRenderingServiceCapture.getEmptyCardsReport()
            }.value
            report = emptyReport.report

            let deckById = (try? capturedDeckClient.fetchAll())?.reduce(into: [Int64: String]()) { partial, deck in
                partial[deck.id] = deck.name
            } ?? [:]

            noteEntries = emptyReport.notes.map { note in
                let cards = (try? capturedCardClient.fetchByNote(note.noteID)) ?? []
                let totalCards = max(cards.count, note.cardIDs.count)
                let deckName = cards.first.flatMap { deckById[$0.did] } ?? "-"
                return NoteEntry(
                    id: note.noteID,
                    cardIds: note.cardIDs,
                    totalCards: totalCards,
                    emptyCards: note.cardIDs.count,
                    deckName: deckName,
                    willDeleteNote: note.willDeleteNote
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    private func deleteAllEmpty() async {
        isDeletingAll = true
        let allCardIds = noteEntries.flatMap { $0.cardIds }
        let cardClientCapture = cardClient
        do {
            try await Task.detached {
                try cardClientCapture.removeCards(allCardIds)
            }.value
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isDeletingAll = false
    }

    private func openNoteEditor(noteId: Int64) async {
        guard let note = try? noteClient.fetch(noteId) else {
            errorMessage = "An unknown error occurred."
            showError = true
            return
        }
        editingNote = note
    }
}
