/// Per-note empty-card cluster surfaced by `Collection.get_empty_cards`.
/// `willDeleteNote` is true when removing the listed cards would leave
/// the note with no cards at all.
public struct EmptyCardsReportNote: Sendable, Equatable {
    public let noteID: NoteID
    public let cardIDs: [CardID]
    public let willDeleteNote: Bool

    public init(noteID: NoteID, cardIDs: [CardID], willDeleteNote: Bool) {
        self.noteID = noteID
        self.cardIDs = cardIDs
        self.willDeleteNote = willDeleteNote
    }
}

/// Full empty-cards report returned by the backend: an opaque
/// human-readable summary plus the per-note clusters.
public struct EmptyCardsReport: Sendable, Equatable {
    public let report: String
    public let notes: [EmptyCardsReportNote]

    public init(report: String, notes: [EmptyCardsReportNote]) {
        self.report = report
        self.notes = notes
    }
}
