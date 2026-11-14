//
//  EmptyCardsView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 29.04.2026.
//

import SwiftUI
import Theme
import UI
import AnkiKit
import BrowseFeature
import CasePaths
import SwiftUINavigation

/// Empty Cards container: owns navigation, the delete/success/error alerts,
/// and the note-editor sheets, and drives an `EmptyCardsModel` for the
/// report scan + card removal. Rendering is delegated to `EmptyCardsContent`.
struct EmptyCardsView: View {
    @State private var model = EmptyCardsModel()
    @Environment(\.dismiss) private var dismiss

    @State private var destination: Destination?

    /// One axis for all three alerts and both editors. The editor split used to
    /// be two `Binding<NoteRecord?>` projections off a single `editingNote` that
    /// each had to filter the other's notes out by hand; as two cases the
    /// branch is taken once, where the note is fetched. The error lives here
    /// too rather than on the model, so no two alerts can ever be true at once.
    @CasePathable
    enum Destination {
        case confirmDeleteAll
        case deleted
        case error(Failure)
        case editNote(NoteRecord)
        case editImageOcclusion(NoteRecord)
    }

    struct Failure {
        let title: String
        let message: String
    }

    var body: some View {
        EmptyCardsContent(
            model: model,
            onOpenNote: { id in Task { await openNote(id) } },
            onRequestDeleteAll: { destination = .confirmDeleteAll }
        )
        .navigationTitle(String(localized: "Empty Cards", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(EmptyCardsPrompts(
            destination: $destination,
            emptyCardCount: model.totalEmptyCards,
            onConfirmDeleteAll: { Task { await deleteAll() } },
            onAcknowledgeDeleted: { dismiss() }
        ))
        .task { await load() }
        .sheet(item: $destination.editNote) { note in
            NoteEditingDestinationView(note: note, embedInNavigationStack: true) {
                Task { await load() }
            }
        }
        .fullScreenCover(item: $destination.editImageOcclusion) { note in
            NoteEditingDestinationView(note: note, embedInNavigationStack: true) {
                Task { await load() }
            }
        }
    }

    private func load() async {
        do {
            try await model.loadEmptyCards()
        } catch {
            destination = .error(.init(
                title: String(localized: "Couldn't load empty cards", bundle: .module),
                message: error.localizedDescription
            ))
        }
    }

    private func deleteAll() async {
        do {
            try await model.deleteAllEmpty()
            destination = .deleted
        } catch {
            destination = .error(.init(
                title: String(localized: "Couldn't delete empty cards", bundle: .module),
                message: error.localizedDescription
            ))
        }
    }

    private func openNote(_ id: NoteID) async {
        do {
            guard let note = try await model.fetchNote(id) else {
                destination = .error(.init(
                    title: String(localized: "Note unavailable", bundle: .module),
                    message: String(localized: "That note no longer exists.", bundle: .module)
                ))
                return
            }
            destination = note.isImageOcclusionNote
                ? .editImageOcclusion(note)
                : .editNote(note)
        } catch {
            destination = .error(.init(
                title: String(localized: "Couldn't open note", bundle: .module),
                message: error.localizedDescription
            ))
        }
    }
}

// MARK: - Prompts

private struct EmptyCardsPrompts: ViewModifier {
    @Binding var destination: EmptyCardsView.Destination?
    let emptyCardCount: Int
    let onConfirmDeleteAll: () -> Void
    let onAcknowledgeDeleted: () -> Void

    private var failure: EmptyCardsView.Failure? {
        guard case .error(let failure) = destination else { return nil }
        return failure
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: "Delete empty cards?", bundle: .module),
                isPresented: $destination.confirmDeleteAll,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Delete", bundle: .module), role: .destructive, action: onConfirmDeleteAll)
                Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
            } message: {
                Text("Delete \(emptyCardCount) empty cards? This cannot be undone.", bundle: .module)
            }
            .alert(String(localized: "Empty cards deleted", bundle: .module), isPresented: $destination.deleted) {
                Button(String(localized: "OK", bundle: .module), role: .cancel, action: onAcknowledgeDeleted)
            }
            .alert(
                Text(failure?.title ?? ""),
                isPresented: Binding($destination.error)
            ) {
                Button(String(localized: "OK", bundle: .module), role: .cancel) {}
            } message: {
                Text(failure?.message ?? String(localized: "An unknown error occurred.", bundle: .module))
            }
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
                    Label(String(localized: "No empty cards found", bundle: .module), systemImage: "checkmark.circle")
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
                String(localized: "Found \(model.totalEmptyCards) notes with empty cards", bundle: .module),
                systemImage: "rectangle.stack.badge.minus"
            )
            .amgiStatusText(.warning)
            .listRowBackground(palette.surfaceElevated)

            if !model.report.isEmpty {
                DisclosureGroup(String(localized: "Report", bundle: .module)) {
                    Text(model.report)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .listRowBackground(palette.surfaceElevated)
            }
        }
    }

    private var affectedNotesSection: some View {
        Section {
            ForEach(model.noteEntries) { entry in
                Button {
                    onOpenNote(entry.id)
                } label: {
                    HStack(alignment: .top, spacing: AmgiSpacing.sm) {
                        VStack(alignment: .leading, spacing: AmgiSpacing.xxs) {
                            Text("Note id: \(entry.id.rawValue)", bundle: .module)
                                .amgiFont(.body, .monospacedDigits)
                                .foregroundStyle(palette.textPrimary)
                            Text("\(entry.emptyCards) of \(entry.totalCards) cards empty", bundle: .module)
                                .amgiFont(.caption)
                                .foregroundStyle(palette.textSecondary)
                            Text("Deck: \(entry.deckName)", bundle: .module)
                                .amgiFont(.caption)
                                .foregroundStyle(palette.textSecondary)
                            if entry.willDeleteNote {
                                Text("Will also delete the note (all cards empty)", bundle: .module)
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
        } header: {
            SettingsListHeader(String(localized: "Affected notes", bundle: .module))
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                onRequestDeleteAll()
            } label: {
                if model.isDeletingAll {
                    HStack {
                        Text("Delete All Empty Cards", bundle: .module)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ProgressView()
                    }
                } else {
                    Label(String(localized: "Delete All Empty Cards…", bundle: .module), systemImage: "trash")
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
