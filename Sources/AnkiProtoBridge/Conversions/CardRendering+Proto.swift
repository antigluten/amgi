package import AnkiKit
package import AnkiProto

// MARK: - RenderedCard

package extension RenderedCard {
    /// Flattens a `RenderCardResponse` into the AnkiKit mirror by joining
    /// each template node's rendered text and lifting the shared CSS.
    init(_ proto: Anki_CardRendering_RenderCardResponse) {
        self.init(
            frontHTML: joinRenderedNodes(proto.questionNodes),
            backHTML:  joinRenderedNodes(proto.answerNodes),
            cardCSS:   proto.css
        )
    }
}

extension RenderedCard: BridgeDecodable {
    package typealias Proto = Anki_CardRendering_RenderCardResponse
}

// MARK: - EmptyCardsReport

package extension EmptyCardsReportNote {
    init(_ proto: Anki_CardRendering_EmptyCardsReport.NoteWithEmptyCards) {
        self.init(
            noteID: NoteID(proto.noteID),
            cardIDs: proto.cardIds.map { CardID($0) },
            willDeleteNote: proto.willDeleteNote
        )
    }
}

package extension EmptyCardsReport {
    init(_ proto: Anki_CardRendering_EmptyCardsReport) {
        self.init(
            report: proto.report,
            notes: proto.notes.map { EmptyCardsReportNote($0) }
        )
    }
}

extension EmptyCardsReport: BridgeDecodable {
    package typealias Proto = Anki_CardRendering_EmptyCardsReport
}

// MARK: - Rendered-template-node joining

/// Joins a sequence of rendered template nodes (literal text + filled
/// replacements) into a single HTML string. Replacement nodes that the
/// backend left unresolved fall back to their `currentText`.
package func joinRenderedNodes(_ nodes: [Anki_CardRendering_RenderedTemplateNode]) -> String {
    nodes.map { node -> String in
        switch node.value {
        case .text(let text):     return text
        case .replacement(let r): return r.currentText
        case .none:               return ""
        }
    }.joined()
}
