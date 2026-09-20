//
//  CardContextMenu.swift
//  AppShared
//
//  Created by Vladimir Gusev on 29.04.2026.
//

public import SwiftUI
import Theme
import AppCore
public import AnkiKit

// MARK: - Menu content

/// The eight flags as an inline palette row rather than a submenu — the same
/// shape Mail and Reminders use for flags and tags. One tap instead of two,
/// and the current flag reads as a selection instead of a nested label.
@MainActor
public struct CardFlagPicker: View {
    let model: CardContextMenuModel
    let cardId: CardID
    var onAction: (_ shouldAdvance: Bool) -> Void

    public init(
        model: CardContextMenuModel,
        cardId: CardID,
        onAction: @escaping (_ shouldAdvance: Bool) -> Void = { _ in }
    ) {
        self.model = model
        self.cardId = cardId
        self.onAction = onAction
    }

    public var body: some View {
        Section {
            Picker("Flag", selection: Binding(
                get: { model.currentFlag & 0b111 },
                set: { value in
                    Task {
                        if let advance = await model.flag(cardId, value) { onAction(advance) }
                    }
                }
            )) {
                ForEach(CardFlag.all, id: \.self) { value in
                    Label(CardFlag.name(value), systemImage: CardFlag.symbol(value))
                        .tint(CardFlag.color(value))
                        .tag(value)
                }
            }
            .pickerStyle(.palette)
        }
    }
}

/// Card and note operations as flat `Section`s — no submenus, so a host can
/// drop them straight into its own `Menu` without nesting. Card-scope and
/// note-scope actions are separated by section rather than by a "Note
/// actions ▸" submenu, and the one destructive action sits alone at the end.
///
/// The error alert, the delete confirmation, the due-date prompt, and the
/// initial state load live in `.cardActionPresentations`, which the host
/// applies *outside* the
/// enclosing `Menu`: presentations attached to menu content never show, and
/// a `.task` there wouldn't run until the menu is opened.
@MainActor
public struct CardActionSections: View {
    let model: CardContextMenuModel
    let cardId: CardID
    var noteId: NoteID?
    @Binding var confirmDeleteNote: Bool
    var onAction: (_ shouldAdvance: Bool) -> Void

    public init(
        model: CardContextMenuModel,
        cardId: CardID,
        noteId: NoteID? = nil,
        confirmDeleteNote: Binding<Bool>,
        onAction: @escaping (_ shouldAdvance: Bool) -> Void = { _ in }
    ) {
        self.model = model
        self.cardId = cardId
        self.noteId = noteId
        self._confirmDeleteNote = confirmDeleteNote
        self.onAction = onAction
    }

    public var body: some View {
        Section {
            Button { act { await model.suspend(cardId) } } label: {
                Label("Suspend Card", systemImage: "pause.circle")
            }
            Button { act { await model.bury(cardId) } } label: {
                Label("Bury Card Until Tomorrow", systemImage: "moon.zzz")
            }
            Button { act { await model.resetToNew(cardId) } } label: {
                Label("Forget Card", systemImage: "arrow.counterclockwise")
            }
            Button { model.showSetDueDate = true } label: {
                Label("Set Due Date", systemImage: "calendar.badge.clock")
            }
        }

        if let noteId {
            Section {
                Button { act { await model.toggleMarked(noteId) } } label: {
                    Label(
                        model.isMarkedNote ? "Unmark Note" : "Mark Note",
                        systemImage: model.isMarkedNote ? "star.slash" : "star"
                    )
                }
                Button { act { await model.suspendNote(noteId) } } label: {
                    Label("Suspend Note", systemImage: "pause.circle.fill")
                }
                Button { act { await model.buryNote(noteId) } } label: {
                    Label("Bury Note", systemImage: "moon.zzz.fill")
                }
            }

            Section {
                Button(role: .destructive) { confirmDeleteNote = true } label: {
                    Label("Delete Note", systemImage: "trash")
                }
            }
        }
    }

    /// Run a model action and forward its outcome. `nil` means the action
    /// failed and the model already raised the error alert.
    private func act(_ body: @escaping () async -> Bool?) {
        Task { if let shouldAdvance = await body() { onAction(shouldAdvance) } }
    }
}

// MARK: - Presentations

extension View {
    /// Error alert, delete confirmation, due-date prompt, and initial load for
    /// `CardActionSections`/`CardFlagPicker`. Apply this to the view that
    /// *hosts* the `Menu`, never inside the menu's content.
    @MainActor
    public func cardActionPresentations(
        model: CardContextMenuModel,
        cardId: CardID?,
        noteId: NoteID?,
        confirmDeleteNote: Binding<Bool>,
        onAction: @escaping (_ shouldAdvance: Bool) -> Void = { _ in }
    ) -> some View {
        modifier(CardActionPresentations(
            model: model,
            cardId: cardId,
            noteId: noteId,
            confirmDeleteNote: confirmDeleteNote,
            onAction: onAction
        ))
    }
}

private struct CardActionPresentations: ViewModifier {
    @Bindable var model: CardContextMenuModel
    let cardId: CardID?
    let noteId: NoteID?
    @Binding var confirmDeleteNote: Bool
    let onAction: (_ shouldAdvance: Bool) -> Void

    func body(content: Content) -> some View {
        content
            .alert("Action failed", isPresented: $model.showError) {
                Button("OK") { }
            } message: {
                Text(model.errorMessage ?? "An unknown error occurred.")
            }
            .confirmationDialog(
                "Delete this note?",
                isPresented: $confirmDeleteNote,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let noteId else { return }
                    Task {
                        if let advance = await model.deleteNote(noteId) { onAction(advance) }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This deletes the note and all its cards. The action cannot be undone.")
            }
            .alert("Set Due Date", isPresented: $model.showSetDueDate) {
                TextField("Days", text: $model.dueDateSpec)
                Button("Set") {
                    guard let cardId else { return }
                    Task {
                        if let advance = await model.setDueDate(cardId, model.dueDateSpec) {
                            onAction(advance)
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("0 = today, 1 = tomorrow, 3-7 = a random day in that range. Append ! to also reset the interval, e.g. 3!.")
            }
            .task(id: cardId) {
                guard let cardId else { return }
                await model.load(cardId: cardId, noteId: noteId)
            }
    }
}

// MARK: - Standalone button

/// Self-contained `…` button wrapping the card actions — used by Browse,
/// where the actions are the whole menu. Reviewing composes the same sections
/// into its own toolbar menu instead, so nothing nests.
@MainActor
public struct CardContextMenu: View {
    let cardId: CardID
    var noteId: NoteID?
    var onSuccess: (() -> Void)?
    var onActionSuccess: ((_ shouldAdvance: Bool) -> Void)?

    @State private var model = CardContextMenuModel()
    @State private var confirmDeleteNote = false

    // Explicit: the `private` state above would otherwise make the synthesized
    // memberwise initializer private too, and Browse constructs this cross-file.
    public init(
        cardId: CardID,
        noteId: NoteID? = nil,
        onSuccess: (() -> Void)? = nil,
        onActionSuccess: ((_ shouldAdvance: Bool) -> Void)? = nil
    ) {
        self.cardId = cardId
        self.noteId = noteId
        self.onSuccess = onSuccess
        self.onActionSuccess = onActionSuccess
    }

    public var body: some View {
        Menu {
            CardFlagPicker(model: model, cardId: cardId, onAction: forward)
            CardActionSections(
                model: model,
                cardId: cardId,
                noteId: noteId,
                confirmDeleteNote: $confirmDeleteNote,
                onAction: forward
            )
            Section {
                Button {
                    Task { if let advance = await model.undo(cardId) { forward(advance) } }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!model.canUndo || model.isUndoing)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .amgiFont(.bodyEmphasis)
        }
        .accessibilityLabel("Card actions")
        .cardActionPresentations(
            model: model,
            cardId: cardId,
            noteId: noteId,
            confirmDeleteNote: $confirmDeleteNote,
            onAction: forward
        )
    }

    private func forward(_ shouldAdvance: Bool) {
        onSuccess?()
        onActionSuccess?(shouldAdvance)
    }
}

#if DEBUG

#Preview {
    VStack(spacing: 20) {
        Text("Tap the menu button below")
            .amgiFont(.bodyEmphasis)

        Spacer()

        HStack {
            Text("Card Menu:")
            CardContextMenu(
                cardId: CardID(12345),
                onSuccess: { print("Action succeeded") }
            )
        }

        Spacer()
    }
    .padding()
}
#endif
