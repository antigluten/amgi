import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Deck loading for the reader configuration screen. The field-mapping
/// values stay as `@Shared(.appStorage)` bindings on the View; the model
/// just owns the one piece of engine I/O so the View carries no
/// `@Dependency`.
@Observable
@MainActor
final class ReaderConfigurationModel {
    var decks: [DeckInfo] = []
    var loadError: String?

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient

    func loadDecks() async {
        do {
            decks = try deckClient.fetchAll().sorted { $0.name < $1.name }
        } catch {
            loadError = "Failed to load decks: \(error.localizedDescription)"
        }
    }
}
