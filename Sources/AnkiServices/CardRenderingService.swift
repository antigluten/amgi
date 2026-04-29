import AnkiBackend
public import AnkiProto
public import AnkiKit
public import Dependencies
import DependenciesMacros

public struct EmptyCardsReportNote: Sendable {
    public let noteID: Int64
    public let cardIDs: [Int64]
    public let willDeleteNote: Bool
}

public struct EmptyCardsReport: Sendable {
    public let report: String
    public let notes: [EmptyCardsReportNote]
}

@DependencyClient
public struct CardRenderingService: Sendable {
    public var renderCard: @Sendable (_ cardId: Int64) throws -> RenderedCard
    public var getEmptyCardsReport: @Sendable () throws -> EmptyCardsReport

    /// Renders a card template that has not yet been saved (uncommitted),
    /// using the provided notetype, template index, and sample field values.
    /// Returns a `RenderedCard` with front and back HTML (CSS injected).
    public var renderUncommittedCard: @Sendable (
        _ notetype: Anki_Notetypes_Notetype,
        _ cardOrdinal: Int,
        _ sampleFields: [String]
    ) throws -> RenderedCard
}

extension CardRenderingService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            renderCard: { cardId in
                var req = Anki_CardRendering_RenderExistingCardRequest()
                req.cardID = cardId
                req.browser = false
                let rendered: Anki_CardRendering_RenderCardResponse = try backend.invoke(
                    service: AnkiBackend.Service.cardRendering,
                    method: AnkiBackend.CardRenderingMethod.renderExistingCard,
                    request: req
                )
                var frontHTML = renderNodes(rendered.questionNodes)
                var backHTML = renderNodes(rendered.answerNodes)
                if !rendered.css.isEmpty {
                    let cssTag = "<style>\(rendered.css)</style>"
                    frontHTML = cssTag + frontHTML
                    backHTML = cssTag + backHTML
                }
                return RenderedCard(frontHTML: frontHTML, backHTML: backHTML)
            },
            getEmptyCardsReport: {
                let resp: Anki_CardRendering_EmptyCardsReport = try backend.invoke(
                    service: AnkiBackend.Service.cardRendering,
                    method: AnkiBackend.CardRenderingMethod.getEmptyCards
                )
                let notes = resp.notes.map { note in
                    EmptyCardsReportNote(
                        noteID: note.noteID,
                        cardIDs: note.cardIds,
                        willDeleteNote: note.willDeleteNote
                    )
                }
                return EmptyCardsReport(report: resp.report, notes: notes)
            },
            renderUncommittedCard: { notetype, cardOrdinal, sampleFields in
                guard notetype.templates.indices.contains(cardOrdinal) else {
                    return RenderedCard(frontHTML: "", backHTML: "")
                }
                var note = Anki_Notes_Note()
                note.notetypeID = notetype.id
                note.fields = sampleFields
                note.tags = []

                var req = Anki_CardRendering_RenderUncommittedCardRequest()
                req.note = note
                req.cardOrd = notetype.templates[cardOrdinal].ord.val
                req.template = notetype.templates[cardOrdinal]
                req.fillEmpty = true
                req.partialRender = false

                let rendered: Anki_CardRendering_RenderCardResponse = try backend.invoke(
                    service: AnkiBackend.Service.cardRendering,
                    method: AnkiBackend.CardRenderingMethod.renderUncommittedCard,
                    request: req
                )

                let notetypeCSS = notetype.config.css
                let cssTag = notetypeCSS.isEmpty ? "" : "<style>\(notetypeCSS)</style>"
                let frontHTML = cssTag + renderNodes(rendered.questionNodes)
                let backHTML = cssTag + renderNodes(rendered.answerNodes)
                return RenderedCard(frontHTML: frontHTML, backHTML: backHTML)
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

private func renderNodes(_ nodes: [Anki_CardRendering_RenderedTemplateNode]) -> String {
    nodes.map { node -> String in
        switch node.value {
        case .text(let text): return text
        case .replacement(let r): return r.currentText
        case .none: return ""
        }
    }.joined()
}
