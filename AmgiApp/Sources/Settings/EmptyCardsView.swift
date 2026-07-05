import SwiftUI
import AmgiTheme
import AnkiKit

/// Empty Cards container: owns navigation, the delete/success/error alerts,
/// and the note-editor sheets, and drives an `EmptyCardsModel` for the
/// report scan + card removal. Rendering is delegated to `EmptyCardsContent`.
struct EmptyCardsView: View {
    @State private var model = EmptyCardsModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var showSuccess = false
    @State private var editingNote: NoteRecord?

    var body: some View {
        EmptyCardsContent(
            model: model,
            onOpenNote: { id in
                Task {
                    if let note = await model.fetchNote(id) { editingNote = note }
                }
            },
            onRequestDeleteAll: { showDeleteConfirm = true }
        )
        .navigationTitle("Empty Cards")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete empty cards?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if await model.deleteAllEmpty() { showSuccess = true }
                }
            }
        } message: {
            Text("Delete \(model.totalEmptyCards) empty cards? This cannot be undone.")
        }
        .alert("Done", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Empty cards deleted.")
        }
        .alert("Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "An unknown error occurred.")
        }
        .task { await model.loadEmptyCards() }
        .sheet(item: regularEditingNoteBinding) { note in
            NoteEditingDestinationView(note: note, embedInNavigationStack: true) {
                Task { await model.loadEmptyCards() }
            }
        }
        .fullScreenCover(item: imageOcclusionEditingNoteBinding) { note in
            NoteEditingDestinationView(note: note, embedInNavigationStack: true) {
                Task { await model.loadEmptyCards() }
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
}

// MARK: - EmptyCardsContent

/// Pure rendering for the Empty Cards screen: the loading spinner, the
/// "found N notes" summary with report disclosure, the affected-notes list,
/// and the delete-all button. Reads state from the model and reports user
/// intent through closures, so it renders in a `#Preview` from a seeded model.
struct EmptyCardsContent: View {
    let model: EmptyCardsModel
    let onOpenNote: (NoteID) -> Void
    let onRequestDeleteAll: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.background)
            } else {
                resultsList
            }
        }
    }

    private var resultsList: some View {
        List {
            if model.noteEntries.isEmpty {
                Section {
                    Label("No empty cards found", systemImage: "checkmark.circle")
                        .amgiStatusText(.positive)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .listRowBackground(palette.surfaceElevated)
                }
            } else {
                summarySection
                affectedNotesSection
                deleteSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
    }

    @ViewBuilder
    private var summarySection: some View {
        Section {
            Label(
                "Found \(model.totalEmptyCards) notes with empty cards",
                systemImage: "rectangle.stack.badge.minus"
            )
            .amgiStatusText(.warning)
            .listRowBackground(palette.surfaceElevated)

            if !model.report.isEmpty {
                DisclosureGroup("Report") {
                    Text(model.report)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .listRowBackground(palette.surfaceElevated)
            }
        }
    }

    private var affectedNotesSection: some View {
        Section("Affected notes") {
            ForEach(model.noteEntries) { entry in
                Button {
                    onOpenNote(entry.id)
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
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                onRequestDeleteAll()
            } label: {
                if model.isDeletingAll {
                    HStack {
                        Text("Delete All Empty Cards")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Label("Delete All Empty Cards", systemImage: "trash")
                }
            }
            .disabled(model.isDeletingAll)
            .listRowBackground(palette.surfaceElevated)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let model = EmptyCardsModel()
    model.isLoading = false
    model.report = "Note 1: 2 of 3 cards empty\nNote 2: 1 of 1 cards empty (note will be deleted)"
    model.noteEntries = [
        .init(id: NoteID(1), cardIds: [CardID(10), CardID(11)], totalCards: 3,
              emptyCards: 2, deckName: "Japanese::Vocabulary", willDeleteNote: false),
        .init(id: NoteID(2), cardIds: [CardID(20)], totalCards: 1,
              emptyCards: 1, deckName: "Default", willDeleteNote: true),
    ]
    return NavigationStack {
        EmptyCardsContent(model: model, onOpenNote: { _ in }, onRequestDeleteAll: {})
            .navigationTitle("Empty Cards")
            .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
