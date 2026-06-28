import SwiftUI
import AmgiTheme
import AnkiKit
import UIKit

/// Context menu for card operations (suspend, bury, flag, undo)
@MainActor
struct CardContextMenu: View {
    let cardId: CardID
    let noteId: NoteID?
    var onSuccess: (() -> Void)?
    var onActionSuccess: ((_ shouldAdvance: Bool) -> Void)?
    var onRequestSetDueDate: ((_ cardId: CardID) -> Void)?

    @Environment(\.palette) private var palette

    @State private var model = CardContextMenuModel()
    @State private var showDeleteConfirmation = false

    init(
        cardId: CardID,
        noteId: NoteID? = nil,
        onSuccess: (() -> Void)? = nil,
        onActionSuccess: ((_ shouldAdvance: Bool) -> Void)? = nil,
        onRequestSetDueDate: ((_ cardId: CardID) -> Void)? = nil
    ) {
        self.cardId = cardId
        self.noteId = noteId
        self.onSuccess = onSuccess
        self.onActionSuccess = onActionSuccess
        self.onRequestSetDueDate = onRequestSetDueDate
    }

    var body: some View {
        Menu {
            Button { forward(model.suspend(cardId)) } label: {
                Label("Suspend", systemImage: "pause.circle")
            }

            Button { forward(model.bury(cardId)) } label: {
                Label("Bury until tomorrow", systemImage: "books.vertical")
            }

            Button { forward(model.resetToNew(cardId)) } label: {
                Label("Forget", systemImage: "arrow.counterclockwise")
            }

            if let onRequestSetDueDate {
                Button {
                    onRequestSetDueDate(cardId)
                } label: {
                    Label("Set due date", systemImage: "calendar.badge.clock")
                }
            }

            if let noteId {
                Menu {
                    Button { forward(model.toggleMarked(noteId)) } label: {
                        Label(
                            model.isMarkedNote ? "Unmark note" : "Mark note",
                            systemImage: model.isMarkedNote ? "star.slash" : "star"
                        )
                    }

                    Button { forward(model.suspendNote(noteId)) } label: {
                        Label("Suspend note", systemImage: "pause.circle.fill")
                    }

                    Button { forward(model.buryNote(noteId)) } label: {
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
                    Image(systemName: model.currentFlag == 0 ? "flag.slash.fill" : "flag.fill")
                        .foregroundStyle(flagColor(for: model.currentFlag))
                }
            }

            Button {
                Task { forward(await model.undo(cardId)) }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo || model.isUndoing)
        } label: {
            Image(systemName: "ellipsis.circle")
                .amgiFont(.bodyEmphasis)
        }
        .accessibilityLabel("Card actions")
        .alert("Action failed", isPresented: $model.showError) {
            Button("OK") { }
        } message: {
            Text(model.errorMessage ?? "An unknown error occurred.")
        }
        .confirmationDialog("Delete this note?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let noteId { forward(model.deleteNote(noteId)) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This deletes the note and all its cards. The action cannot be undone.")
        }
        .task(id: cardId) {
            await model.load(cardId: cardId, noteId: noteId)
        }
    }

}

private extension CardContextMenu {
    /// Forward a model action outcome to the parent callbacks. `nil` means
    /// the action failed (the model already surfaced the error alert).
    func forward(_ shouldAdvance: Bool?) {
        guard let shouldAdvance else { return }
        onSuccess?()
        onActionSuccess?(shouldAdvance)
    }

    func flagButton(_ value: UInt32) -> some View {
        let tint = flagColor(for: value)
        return Button(action: { forward(model.flag(cardId, value)) }) {
            Label {
                Text(flagDisplayName(for: value))
                    .foregroundStyle(tint)
            } icon: {
                flagMenuIcon(for: value)
            }
        }
    }

    func flagDisplayName(for value: UInt32) -> String {
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

    func flagMenuIcon(for value: UInt32) -> Image {
        let symbolName = value == 0 ? "flag.slash.fill" : "flag.fill"
        let tint = UIColor(flagColor(for: value))
        if let image = UIImage(systemName: symbolName)?.withTintColor(tint, renderingMode: .alwaysOriginal) {
            return Image(uiImage: image)
        }
        return Image(systemName: symbolName)
    }

    func flagColor(for value: UInt32) -> Color {
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
