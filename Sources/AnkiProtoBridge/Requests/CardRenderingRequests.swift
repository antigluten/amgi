import Foundation
public import AnkiBackend
public import AnkiKit
import AnkiProto
import SwiftProtobuf

// MARK: - renderCard (existing)

extension Request where Response == RenderedCard {
    /// Renders a card that is already saved in the collection.
    /// `browser: false` selects the reviewer-side template variant.
    public static func renderExistingCard(cardId: CardID) -> Self {
        .decoded(
            serviceId: ServiceID.cardRendering,
            methodId: CardRenderingMethod.renderExistingCard,
            encode: {
                var proto = Anki_CardRendering_RenderExistingCardRequest()
                proto.cardID = cardId.rawValue
                proto.browser = false
                return try proto.serializedData()
            }
        )
    }

    /// Renders an uncommitted template against `sampleFields`. Used by
    /// notetype/template editors to preview before save.
    /// `template.toProto()` lives in AnkiProtoBridge — callers pass the
    /// AnkiKit mirror directly.
    public static func renderUncommittedCard(
        notetypeId: NotetypeID,
        template: Notetype.Template,
        cardOrd: UInt32,
        sampleFields: [String]
    ) -> Self {
        .decoded(
            serviceId: ServiceID.cardRendering,
            methodId: CardRenderingMethod.renderUncommittedCard,
            encode: {
                var note = Anki_Notes_Note()
                note.notetypeID = notetypeId.rawValue
                note.fields = sampleFields
                note.tags = []

                var proto = Anki_CardRendering_RenderUncommittedCardRequest()
                proto.note = note
                proto.cardOrd = cardOrd
                proto.template = template.toProto()
                proto.fillEmpty = true
                proto.partialRender = false
                return try proto.serializedData()
            }
        )
    }
}

// MARK: - getEmptyCardsReport

extension Request where Response == EmptyCardsReport {
    /// Backend collation of all notes with empty cards. No request body —
    /// the backend infers context from the open collection.
    public static var getEmptyCardsReport: Self {
        .decoded(
            serviceId: ServiceID.cardRendering,
            methodId: CardRenderingMethod.getEmptyCards
        )
    }
}

// MARK: - compareAnswer / extractClozeForTyping (String response)

extension Request where Response == String {
    /// Produces colored diff HTML between `expected` and `provided`,
    /// honouring combining-character normalization when `combining` is true.
    public static func compareAnswer(expected: String, provided: String, combining: Bool) -> Self {
        Self(
            serviceId: ServiceID.cardRendering,
            methodId: CardRenderingMethod.compareAnswer,
            encode: {
                var proto = Anki_CardRendering_CompareAnswerRequest()
                proto.expected = expected
                proto.provided = provided
                proto.combining = combining
                return try proto.serializedData()
            },
            decode: { bytes in
                try Anki_Generic_String(serializedBytes: bytes).val
            }
        )
    }

    /// Returns the expected text for the cloze at `ordinal` inside `text`.
    public static func extractClozeForTyping(text: String, ordinal: UInt32) -> Self {
        Self(
            serviceId: ServiceID.cardRendering,
            methodId: CardRenderingMethod.extractClozeForTyping,
            encode: {
                var proto = Anki_CardRendering_ExtractClozeForTypingRequest()
                proto.text = text
                proto.ordinal = ordinal
                return try proto.serializedData()
            },
            decode: { bytes in
                try Anki_Generic_String(serializedBytes: bytes).val
            }
        )
    }
}
