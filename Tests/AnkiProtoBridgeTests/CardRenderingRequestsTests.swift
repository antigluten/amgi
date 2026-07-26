import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto
private import SwiftProtobuf

@Suite struct CardRenderingRequestsTests {
    // MARK: - renderExistingCard

    @Test func renderExistingCard_dispatches_and_encodes_cardId() throws {
        let envelope: Request<RenderedCard> = .renderExistingCard(cardId: CardID(42))
        #expect(envelope.serviceId == ServiceID.cardRendering)
        #expect(envelope.methodId == CardRenderingMethod.renderExistingCard)
        let proto = try Anki_CardRendering_RenderExistingCardRequest(serializedBytes: envelope.body)
        #expect(proto.cardID == 42)
        #expect(!proto.browser)
    }

    @Test func renderExistingCard_decodes_question_answer_and_css() throws {
        var q1 = Anki_CardRendering_RenderedTemplateNode()
        q1.text = "front "
        var q2 = Anki_CardRendering_RenderedTemplateNode()
        var repl = Anki_CardRendering_RenderedTemplateReplacement()
        repl.currentText = "FILLED"
        q2.replacement = repl

        var a1 = Anki_CardRendering_RenderedTemplateNode()
        a1.text = "back"

        var resp = Anki_CardRendering_RenderCardResponse()
        resp.questionNodes = [q1, q2]
        resp.answerNodes = [a1]
        resp.css = "h1 { color: red }"
        let bytes = try resp.serializedData()

        let envelope: Request<RenderedCard> = .renderExistingCard(cardId: CardID(1))
        let card = try envelope.decode(bytes)
        #expect(card.frontHTML == "front FILLED")
        #expect(card.backHTML == "back")
        #expect(card.cardCSS == "h1 { color: red }")
    }

    // MARK: - getEmptyCardsReport

    @Test func getEmptyCardsReport_dispatches_with_empty_body() throws {
        let envelope: Request<EmptyCardsReport> = .getEmptyCardsReport
        #expect(envelope.serviceId == ServiceID.cardRendering)
        #expect(envelope.methodId == CardRenderingMethod.getEmptyCards)
        #expect(try envelope.body.isEmpty)
    }

    @Test func getEmptyCardsReport_decodes_report_and_note_clusters() throws {
        var note = Anki_CardRendering_EmptyCardsReport.NoteWithEmptyCards()
        note.noteID = 100
        note.cardIds = [10, 11, 12]
        note.willDeleteNote = true

        var resp = Anki_CardRendering_EmptyCardsReport()
        resp.report = "1 note, 3 cards"
        resp.notes = [note]
        let bytes = try resp.serializedData()

        let envelope: Request<EmptyCardsReport> = .getEmptyCardsReport
        let report = try envelope.decode(bytes)
        #expect(report.report == "1 note, 3 cards")
        #expect(report.notes.count == 1)
        #expect(report.notes.first?.noteID == NoteID(100))
        #expect(report.notes.first?.cardIDs == [CardID(10), CardID(11), CardID(12)])
        #expect(report.notes.first?.willDeleteNote == true)
    }

    // MARK: - compareAnswer

    @Test func compareAnswer_dispatches_and_encodes_inputs() throws {
        let envelope: Request<String> = .compareAnswer(expected: "annyeong", provided: "annyong", combining: true)
        #expect(envelope.serviceId == ServiceID.cardRendering)
        #expect(envelope.methodId == CardRenderingMethod.compareAnswer)
        let proto = try Anki_CardRendering_CompareAnswerRequest(serializedBytes: envelope.body)
        #expect(proto.expected == "annyeong")
        #expect(proto.provided == "annyong")
        #expect(proto.combining)
    }

    @Test func compareAnswer_decodes_string_value() throws {
        var resp = Anki_Generic_String()
        resp.val = "<span class='diff'>match</span>"
        let bytes = try resp.serializedData()
        let envelope: Request<String> = .compareAnswer(expected: "", provided: "", combining: false)
        #expect(try envelope.decode(bytes) == "<span class='diff'>match</span>")
    }

    // MARK: - extractClozeForTyping

    @Test func extractClozeForTyping_dispatches_and_encodes_inputs() throws {
        let envelope: Request<String> = .extractClozeForTyping(text: "{{c1::hello}}", ordinal: 1)
        #expect(envelope.serviceId == ServiceID.cardRendering)
        #expect(envelope.methodId == CardRenderingMethod.extractClozeForTyping)
        let proto = try Anki_CardRendering_ExtractClozeForTypingRequest(serializedBytes: envelope.body)
        #expect(proto.text == "{{c1::hello}}")
        #expect(proto.ordinal == 1)
    }
}
