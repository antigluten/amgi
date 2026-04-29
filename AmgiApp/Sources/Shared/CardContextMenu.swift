import SwiftUI
import AmgiTheme
import AnkiClients
import Dependencies
import UIKit

/// Context menu for card operations (suspend, bury, flag, undo)
@MainActor
struct CardContextMenu: View {
    let cardId: Int64
    let noteId: Int64?
    var onSuccess: (() -> Void)?
    var onActionSuccess: ((_ shouldAdvance: Bool) -> Void)?
    var onRequestSetDueDate: ((_ cardId: Int64) -> Void)?

    @Dependency(\.cardClient) var cardClient
    @Dependency(\.noteClient) var noteClient
    @Dependency(\.tagClient) var tagClient

    @Environment(\.palette) private var palette

    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showDeleteConfirmation = false
    @State private var isMarkedNote = false
    @State private var currentFlag: UInt32 = 0
    @State private var canUndo = false
    @State private var isUndoing = false

    init(
        cardId: Int64,
        noteId: Int64? = nil,
        onSuccess: (() -> Void)? = nil,
        onActionSuccess: ((_ shouldAdvance: Bool) -> Void)? = nil,
        onRequestSetDueDate: ((_ cardId: Int64) -> Void)? = nil
    ) {
        self.cardId = cardId
        self.noteId = noteId
        self.onSuccess = onSuccess
        self.onActionSuccess = onActionSuccess
        self.onRequestSetDueDate = onRequestSetDueDate
    }

    var body: some View {
        Menu {
            Button(action: performSuspend) {
                Label("Suspend", systemImage: "pause.circle")
            }

            Button(action: performBury) {
                Label("Bury until tomorrow", systemImage: "books.vertical")
            }

            Button(action: performResetToNew) {
                Label("Reset to new", systemImage: "arrow.counterclockwise")
            }

            if let onRequestSetDueDate {
                Button {
                    onRequestSetDueDate(cardId)
                } label: {
                    Label("Set due date", systemImage: "calendar.badge.clock")
                }
            }

            if noteId != nil {
                Menu {
                    Button(action: performToggleMarkedNote) {
                        Label(
                            isMarkedNote ? "Unmark note" : "Mark note",
                            systemImage: isMarkedNote ? "star.slash" : "star"
                        )
                    }

                    Button(action: performSuspendNote) {
                        Label("Suspend note", systemImage: "pause.circle.fill")
                    }

                    Button(action: performBuryNote) {
                        Label("Bury note", systemImage: "books.vertical.fill")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete note", systemImage: "trash")
                    }
                } label: {
                    Label("Note actions", systemImage: "note.text")
                }
            }

            Menu {
                // Listed in reverse so iOS bottom-anchored menus display 1→7 top–to–bottom
                flagButton(0)
                flagButton(7)
                flagButton(6)
                flagButton(5)
                flagButton(4)
                flagButton(3)
                flagButton(2)
                flagButton(1)
            } label: {
                Label {
                    Text("Flag")
                } icon: {
                    Image(systemName: currentFlag == 0 ? "flag.slash.fill" : "flag.fill")
                        .foregroundStyle(flagColor(for: currentFlag))
                }
            }

            Button {
                Task { await performUndo() }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!canUndo || isUndoing)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(AmgiFont.bodyEmphasis.font)
        }
        .alert("Action failed", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
        .confirmationDialog("Delete this note?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: performDeleteNote)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This deletes the note and all its cards. The action cannot be undone.")
        }
        .task(id: cardId) {
            await loadMarkedState()
            await loadCurrentFlag()
            await refreshUndoAvailability()
        }
    }

    private func performSuspend() {
        do {
            try cardClient.suspend(cardId)
            onSuccess?()
            onActionSuccess?(true)
        } catch {
            errorMessage = "Suspend failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func performBury() {
        do {
            try cardClient.bury(cardId)
            onSuccess?()
            onActionSuccess?(true)
        } catch {
            errorMessage = "Bury failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func performSuspendNote() {
        performNoteAction(
            action: { cardId in try cardClient.suspend(cardId) },
            errorMessage: { err in "Suspend note failed: \(err)" }
        )
    }

    private func performBuryNote() {
        performNoteAction(
            action: { cardId in try cardClient.bury(cardId) },
            errorMessage: { err in "Bury note failed: \(err)" }
        )
    }

    private func performResetToNew() {
        do {
            try cardClient.resetToNew(cardId)
            onSuccess?()
            onActionSuccess?(true)
        } catch {
            errorMessage = "Reset to new failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func performDeleteNote() {
        guard let noteId else { return }
        do {
            try noteClient.delete(noteId)
            onSuccess?()
            onActionSuccess?(true)
        } catch {
            errorMessage = "Delete note failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func performToggleMarkedNote() {
        guard let noteId else { return }
        do {
            if isMarkedNote {
                try tagClient.removeTagFromNotes(markedTag, [noteId])
            } else {
                try tagClient.addTagToNotes(markedTag, [noteId])
            }
            isMarkedNote.toggle()
            onSuccess?()
            onActionSuccess?(false)
        } catch {
            errorMessage = "Mark note failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func performNoteAction(
        action: (Int64) throws -> Void,
        errorMessage buildMessage: (String) -> String
    ) {
        guard let noteId else { return }
        do {
            let cards = try cardClient.fetchByNote(noteId)
            for card in cards {
                try action(card.id)
            }
            onSuccess?()
            onActionSuccess?(true)
        } catch {
            errorMessage = buildMessage(error.localizedDescription)
            showError = true
        }
    }

    private func performFlag(_ value: UInt32) {
        do {
            try cardClient.flag(cardId, value)
            currentFlag = value
            onSuccess?()
            onActionSuccess?(false)
        } catch {
            errorMessage = "Flag failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func performUndo() async {
        guard !isUndoing, canUndo else { return }
        isUndoing = true
        defer { isUndoing = false }
        do {
            try cardClient.undoLast()
            onSuccess?()
            onActionSuccess?(true)
        } catch {
            errorMessage = "Undo failed: \(error.localizedDescription)"
            showError = true
            await refreshUndoAvailability()
        }
    }

    private func refreshUndoAvailability() async {
        canUndo = (try? cardClient.hasUndoableAction()) ?? false
    }

    private func flagButton(_ value: UInt32) -> some View {
        let tint = flagColor(for: value)
        return Button(action: { performFlag(value) }) {
            Label {
                Text(flagDisplayName(for: value))
                    .foregroundStyle(tint)
            } icon: {
                flagMenuIcon(for: value)
            }
        }
    }

    private func flagDisplayName(for value: UInt32) -> String {
        switch value & 0b111 {
        case 1: return "Red"
        case 2: return "Orange"
        case 3: return "Green"
        case 4: return "Blue"
        case 5: return "Pink"
        case 6: return "Cyan"
        case 7: return "Purple"
        default: return "None"
        }
    }

    private func flagMenuIcon(for value: UInt32) -> Image {
        let symbolName = value == 0 ? "flag.slash.fill" : "flag.fill"
        let tint = UIColor(flagColor(for: value))
        if let image = UIImage(systemName: symbolName)?.withTintColor(tint, renderingMode: .alwaysOriginal) {
            return Image(uiImage: image)
        }
        return Image(systemName: symbolName)
    }

    private func loadMarkedState() async {
        guard let noteId else {
            isMarkedNote = false
            return
        }

        do {
            let note = try noteClient.fetch(noteId)
            isMarkedNote = note.map {
                $0.tags
                    .split(separator: " ")
                    .contains { $0.caseInsensitiveCompare(markedTag) == .orderedSame }
            } ?? false
        } catch {
            isMarkedNote = false
        }
    }

    private func loadCurrentFlag() async {
        currentFlag = (try? cardClient.getCardFlags(cardId)) ?? 0
    }

    private func flagColor(for value: UInt32) -> Color {
        switch value & 0b111 {
        case 1: return .red
        case 2: return .orange
        case 3: return .green
        case 4: return .blue
        case 5: return .pink
        case 6: return .cyan
        case 7: return .purple
        default: return .secondary
        }
    }
}

private let markedTag = "marked"

#Preview {
    VStack(spacing: 20) {
        Text("Tap the menu button below")
            .amgiFont(.bodyEmphasis)

        Spacer()

        HStack {
            Text("Card Menu:")
            CardContextMenu(
                cardId: 12345,
                onSuccess: { print("Action succeeded") }
            )
        }

        Spacer()
    }
    .padding()
}
