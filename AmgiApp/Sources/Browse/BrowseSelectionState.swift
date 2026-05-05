import Foundation

struct BrowseSelectionState: Equatable, Sendable {
    var isSelectMode: Bool = false
    var selectedNoteIDs: Set<Int64> = []

    var isEmpty: Bool { selectedNoteIDs.isEmpty }
    var count: Int { selectedNoteIDs.count }

    mutating func enterSelectMode(preselect: Int64? = nil) {
        isSelectMode = true
        selectedNoteIDs = preselect.map { [$0] } ?? []
    }

    mutating func exitSelectMode() {
        isSelectMode = false
        selectedNoteIDs = []
    }

    mutating func toggle(_ id: Int64) {
        if selectedNoteIDs.contains(id) {
            selectedNoteIDs.remove(id)
        } else {
            selectedNoteIDs.insert(id)
        }
    }

    func contains(_ id: Int64) -> Bool {
        selectedNoteIDs.contains(id)
    }
}
