import AnkiBackend
import AnkiProto
public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct CardRenderingService: Sendable {
    public var renderCard: @Sendable (_ cardId: Int64) throws -> RenderedCard
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
