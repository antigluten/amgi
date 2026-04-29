import SwiftUI
import AnkiKit
import AmgiTheme

struct NoteEditingDestinationView: View {
    let note: NoteRecord
    let embedInNavigationStack: Bool
    let onSave: () -> Void

    init(note: NoteRecord, embedInNavigationStack: Bool = false, onSave: @escaping () -> Void) {
        self.note = note
        self.embedInNavigationStack = embedInNavigationStack
        self.onSave = onSave
    }

    var body: some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    destinationBody
                }
            } else {
                destinationBody
            }
        }
    }

    @ViewBuilder
    private var destinationBody: some View {
        if note.isImageOcclusionNote {
            EditImageOcclusionNoteView(
                noteId: note.id,
                onSave: onSave,
                embedInNavigationStack: false
            )
        } else {
            NoteEditorView(note: note, onSave: onSave)
        }
    }
}

extension NoteRecord {
    var isImageOcclusionNote: Bool {
        flds.contains("image-occlusion:")
    }
}
