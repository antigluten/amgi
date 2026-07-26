/// Snapshot of orphan vs. missing media files surfaced by Anki's
/// media-check pass.
public struct MediaCheckResult: Sendable, Equatable {
    public let missing: [String]
    public let unused: [String]
    public let missingNoteIDs: [NoteID]
    public let report: String
    public let haveTrash: Bool

    public init(
        missing: [String],
        unused: [String],
        missingNoteIDs: [NoteID],
        report: String,
        haveTrash: Bool
    ) {
        self.missing = missing
        self.unused = unused
        self.missingNoteIDs = missingNoteIDs
        self.report = report
        self.haveTrash = haveTrash
    }
}
