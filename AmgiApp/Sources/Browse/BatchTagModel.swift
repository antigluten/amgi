import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Tag listing + batch-apply I/O for the browse multi-select tag sheet. Owns
/// the `tagClient` dependency, the known-tags list, and the apply-in-flight
/// flag so the view carries no `@Dependency`; the per-tag checkbox selection
/// and the new-tag draft stay on the view.
@Observable
@MainActor
final class BatchTagModel {
    var allTags: [String] = []
    var isApplying = false

    @ObservationIgnored @Dependency(\.tagClient) private var tagClient

    func loadTags() async {
        if let tags = try? await tagClient.getAllTags() {
            allTags = tags.sorted()
        }
    }

    func apply(noteIDs: Set<NoteID>, tags: Set<String>) async {
        isApplying = true
        let ids = Array(noteIDs)
        for tag in tags {
            try? await tagClient.addTagToNotes(tag, ids)
        }
        isApplying = false
    }
}
