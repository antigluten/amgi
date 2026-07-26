import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Notetype listing + mutation I/O for the card-templates screen. Owns the
/// `notetypesClient` dependency and the engine-coupled state (entries, the
/// load flag, and the load/action errors) so the view carries no
/// `@Dependency`; selection and search UI state stay on the view.
@Observable
@MainActor
final class DeckTemplateListModel {
    var entries: [NotetypeNameId] = []
    var isLoading = true
    var errorMessage: String?
    var actionError: String?
    var showActionError = false

    @ObservationIgnored @Dependency(\.notetypesClient) private var notetypesClient

    func loadTemplates() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let allEntries = try notetypesClient.listAll()
            entries = sortDeckTemplateEntries(allEntries)
            errorMessage = nil
        } catch {
            entries = []
            errorMessage = error.localizedDescription
        }
    }

    func rename(_ target: NotetypeNameId, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != target.name else { return }

        do {
            var notetype: Notetype = try notetypesClient.get(target.id)
            notetype.name = trimmed
            try notetypesClient.update(notetype)
            await loadTemplates()
        } catch {
            actionError = "Rename failed: \(error.localizedDescription)"
            showActionError = true
        }
    }

    func delete(_ target: NotetypeNameId) async {
        do {
            try notetypesClient.remove(target.id)
            await loadTemplates()
        } catch {
            actionError = "Delete failed: \(error.localizedDescription)"
            showActionError = true
        }
    }
}
