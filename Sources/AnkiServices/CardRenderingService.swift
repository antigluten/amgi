import AnkiBackend
import AnkiProtoBridge
public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct CardRenderingService: Sendable {
    public var renderCard: @Sendable (_ cardId: CardID) throws -> RenderedCard
    public var getEmptyCardsReport: @Sendable () throws -> EmptyCardsReport

    /// Renders a card template that has not yet been saved (uncommitted),
    /// using the provided notetype, template index, and sample field values.
    /// Returns a `RenderedCard` with front and back HTML; CSS is in `cardCSS`.
    public var renderUncommittedCard: @Sendable (
        _ notetype: Notetype,
        _ cardOrdinal: Int,
        _ sampleFields: [String]
    ) throws -> RenderedCard

    /// Compares the expected answer text against the user-provided typed answer
    /// and returns colored diff HTML (correct chars green, incorrect red).
    /// `combining` controls Unicode combining-character handling.
    public var compareAnswer: @Sendable (
        _ expected: String,
        _ provided: String,
        _ combining: Bool
    ) throws -> String

    /// Extracts the expected text for a cloze typed-answer at the given ordinal.
    public var extractClozeForTyping: @Sendable (
        _ text: String,
        _ ordinal: UInt32
    ) throws -> String
}

extension CardRenderingService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            renderCard: { cardId in
                try backend.invoke(.renderExistingCard(cardId: cardId))
            },
            getEmptyCardsReport: {
                try backend.invoke(.getEmptyCardsReport)
            },
            renderUncommittedCard: { notetype, cardOrdinal, sampleFields in
                guard notetype.templates.indices.contains(cardOrdinal) else {
                    return RenderedCard(frontHTML: "", backHTML: "", cardCSS: "")
                }
                let template = notetype.templates[cardOrdinal]
                return try backend.invoke(.renderUncommittedCard(
                    notetypeId: notetype.id,
                    template: template,
                    cardOrd: UInt32(template.ord ?? 0),
                    sampleFields: sampleFields
                ))
            },
            compareAnswer: { expected, provided, combining in
                try backend.invoke(.compareAnswer(expected: expected, provided: provided, combining: combining))
            },
            extractClozeForTyping: { text, ordinal in
                try backend.invoke(.extractClozeForTyping(text: text, ordinal: ordinal))
            }
        )
    }()
}

extension CardRenderingService: TestDependencyKey {
    public static let testValue = CardRenderingService()
}

extension DependencyValues {
    public var cardRenderingService: CardRenderingService {
        get { self[CardRenderingService.self] }
        set { self[CardRenderingService.self] = newValue }
    }
}
