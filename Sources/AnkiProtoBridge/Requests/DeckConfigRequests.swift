import Foundation
public import AnkiBackend
public import AnkiKit
import AnkiProto
import SwiftProtobuf

// MARK: - getDeckConfig

extension Request where Response == DeckConfig {
    /// Loads the `DeckConfig` for a given preset id.
    public static func deckConfig(for id: DeckConfigID) -> Self {
        .decoded(
            serviceId: ServiceID.deckConfig,
            methodId: DeckConfigMethod.getDeckConfig,
            encode: {
                var req = Anki_DeckConfig_DeckConfigId()
                req.dcid = id.rawValue
                return try req.serializedData()
            }
        )
    }
}

// MARK: - getDeckConfigsForUpdate

extension Request where Response == DeckConfigsForUpdate {
    /// Returns the preset list, current-deck metadata, defaults, and
    /// FSRS toggles for the deck that owns the supplied id.
    public static func deckConfigsForUpdate(deckId: DeckID) -> Self {
        .decoded(
            serviceId: ServiceID.deckConfig,
            methodId: DeckConfigMethod.getDeckConfigsForUpdate,
            encode: {
                var req = Anki_Decks_DeckId()
                req.did = deckId.rawValue
                return try req.serializedData()
            }
        )
    }
}

// MARK: - updateDeckConfigs

extension Request where Response == Void {
    /// Saves preset edits, applies the deck switch, or triggers a
    /// global FSRS-param recompute depending on `request.mode`.
    public static func updateDeckConfigs(_ request: UpdateDeckConfigsRequest) -> Self {
        Self(
            serviceId: ServiceID.deckConfig,
            methodId: DeckConfigMethod.updateDeckConfigs,
            encode: { try request.toProto().serializedData() },
            decode: { _ in () }
        )
    }
}
