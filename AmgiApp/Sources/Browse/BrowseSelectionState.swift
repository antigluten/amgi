import Foundation
import AnkiKit

struct BrowseSelectionState: Equatable, Sendable {
    var isSelectMode: Bool = false
    var selectedNoteIDs: Set<NoteID> = []

    var isEmpty: Bool { selectedNoteIDs.isEmpty }
    var count: Int { selectedNoteIDs.count }

    mutating func enterSelectMode(preselect: NoteID? = nil) {
        isSelectMode = true
        selectedNoteIDs = preselect.map { [$0] } ?? []
    }

    mutating func exitSelectMode() {
        isSelectMode = false
        selectedNoteIDs = []
    }

    mutating func toggle(_ id: NoteID) {
        if selectedNoteIDs.contains(id) {
            selectedNoteIDs.remove(id)
        } else {
            selectedNoteIDs.insert(id)
        }
    }

    func contains(_ id: NoteID) -> Bool {
        selectedNoteIDs.contains(id)
    }
}
