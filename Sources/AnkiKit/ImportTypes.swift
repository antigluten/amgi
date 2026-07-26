/// Summary counts for an .apkg import, mirrored from
/// `Anki_ImportExport_ImportResponse.Log`. Exposes the most commonly
/// surfaced buckets; expand as UI needs grow.
public struct ImportLogSummary: Sendable, Equatable {
    public let newCount: Int
    public let updatedCount: Int
    public let duplicateCount: Int

    public init(newCount: Int, updatedCount: Int, duplicateCount: Int) {
        self.newCount = newCount
        self.updatedCount = updatedCount
        self.duplicateCount = duplicateCount
    }
}
