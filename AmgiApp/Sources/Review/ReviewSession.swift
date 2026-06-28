import SwiftUI
import UIKit
import AnkiKit
import AnkiServices
import Dependencies
import Foundation

@Observable @MainActor
final class ReviewSession {
    let deckId: Int64

    @ObservationIgnored @Dependency(\.decksService) var decks
    @ObservationIgnored @Dependency(\.schedulerService) var scheduler
    @ObservationIgnored @Dependency(\.cardRenderingService) var cardRendering
    @ObservationIgnored @Dependency(\.collectionService) var collection
    @ObservationIgnored @Dependency(\.notesService) var notes
    @ObservationIgnored @Dependency(\.notetypesService) var notetypes

    private(set) var frontHTML: String = ""
    private(set) var backHTML: String = ""
    private(set) var cardCSS: String = ""
    private(set) var showAnswer: Bool = false
    private(set) var sessionStats: SessionStats = .init()
    private(set) var remainingCounts: DeckCounts = .zero
    private(set) var isFinished: Bool = false
    private(set) var canUndo: Bool = false
    private(set) var nextIntervals: [Rating: String] = [:]
    private(set) var typedAnswerRequestID: Int = 0
    private(set) var replayRequestID: Int = 0       // plumbed; consumer is PR 1b
    private(set) var stopAudioRequestID: Int = 0    // plumbed; consumer is PR 1b
    private(set) var isAudioPlaying: Bool = false
    private(set) var currentNote: NoteRecord?
    private(set) var cardChromeColor: Color = .clear
    private(set) var cardChromeIsDark: Bool = false

    private var reviewStartTime: Date = .now
    private var cardQueue: [QueuedReviewCard] = []
    private var currentQueuedCard: QueuedReviewCard?
    private var lastRating: Rating? = nil

    // Typed-answer state
    private var renderedFrontHTML: String = ""
    private var renderedBackHTML: String = ""
    private var typedAnswerState: TypedAnswerState?
    private var typedAnswerContinuation: CheckedContinuation<String?, Never>?

    // MARK: - Computed

    var requiresTypedAnswerInput: Bool {
        typedAnswerState != nil && !showAnswer
    }

    var currentCardOrdinal: UInt32 {
        UInt32(currentQueuedCard?.card.ord ?? 0)
    }

    struct TemplateTarget: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public let notetypeId: Int64
        public let ordinal: Int

        public static func == (lhs: TemplateTarget, rhs: TemplateTarget) -> Bool {
            lhs.notetypeId == rhs.notetypeId && lhs.ordinal == rhs.ordinal
        }
    }

    var currentTemplateTarget: TemplateTarget? {
        guard let card = currentQueuedCard?.card, let note = currentNote else { return nil }
        return TemplateTarget(notetypeId: note.mid, ordinal: Int(card.ord))
    }

    var currentCardId: Int64? {
        currentQueuedCard?.card.id
    }

    /// Bottom 3 bits of the current card's flags field — the flag color
    /// index (0 = none, 1–7 = red/orange/green/blue/pink/cyan/purple).
    /// Mirrors the masking convention used by `cardClient.getCardFlags`.
    var currentFlag: UInt32 {
        UInt32(currentQueuedCard?.card.flags ?? 0) & 0b111
    }

    // MARK: - Init

    init(deckId: Int64) {
        self.deckId = deckId
    }

    // MARK: - Public interface

    func start() {
        do {
            try decks.setCurrentDeck(deckId)

            let result = try scheduler.getQueuedCards(200)
            cardQueue = result.cards
            remainingCounts = DeckCounts(
                newCount: result.newCount,
                learnCount: result.learningCount,
                reviewCount: result.reviewCount
            )
            print("[ReviewSession] Started with \(cardQueue.count) cards, counts: new=\(result.newCount) learn=\(result.learningCount) review=\(result.reviewCount)")
            advanceToNextCard()
        } catch {
            print("[ReviewSession] Start failed: \(error)")
            isFinished = true
        }
    }

    func revealAnswer() async {
        if typedAnswerState == nil {
            backHTML = strippingTypedAnswerPlaceholders(from: renderedBackHTML)
            showAnswer = true
            return
        }

        typedAnswerRequestID += 1  // triggers JS to read <input> via updateUIView

        let typed = await readTypedAnswerWithTimeout()
        if let state = typedAnswerState {
            backHTML = makeTypedAnswerBackHTML(state: state, typedAnswer: typed ?? "")
        } else {
            backHTML = strippingTypedAnswerPlaceholders(from: renderedBackHTML)
        }
        showAnswer = true
    }

    /// Called by CardWebViewCoordinator when JS delivers the typed answer.
    func submitTypedAnswer(_ typed: String?) {
        typedAnswerContinuation?.resume(returning: typed)
        typedAnswerContinuation = nil
    }

    func answer(rating: Rating) {
        guard let queued = currentQueuedCard else { return }

        let timeSpent = UInt32(Date.now.timeIntervalSince(reviewStartTime) * 1000)

        do {
            try scheduler.answerReviewCard(queued.card.id, rating, timeSpent, queued.states)

            sessionStats.reviewed += 1
            if rating != .again { sessionStats.correct += 1 }
            sessionStats.totalTimeMs += Int(timeSpent)
            lastRating = rating
            canUndo = true

            let result = try scheduler.getQueuedCards(200)
            cardQueue = result.cards
            remainingCounts = DeckCounts(
                newCount: result.newCount,
                learnCount: result.learningCount,
                reviewCount: result.reviewCount
            )
            advanceToNextCard()
        } catch {
            print("[ReviewSession] Answer failed: \(error)")
            if !cardQueue.isEmpty { cardQueue.removeFirst() }
            advanceToNextCard()
        }
    }

    func undo() {
        guard canUndo else { return }

        do {
            try collection.undoLast()
            canUndo = false

            // Roll back session stats
            sessionStats.reviewed -= 1
            if let last = lastRating, last != .again {
                sessionStats.correct -= 1
            }
            lastRating = nil

            // Re-fetch queue — Anki places the undone card at the front
            let result = try scheduler.getQueuedCards(200)
            cardQueue = result.cards
            remainingCounts = DeckCounts(
                newCount: result.newCount,
                learnCount: result.learningCount,
                reviewCount: result.reviewCount
            )
            advanceToNextCard()
        } catch {
            print("[ReviewSession] Undo failed: \(error)")
        }
    }

    func updateAudioPlaying(_ playing: Bool) {
        isAudioPlaying = playing
    }

    func updateCardChrome(color: UIColor, isDark: Bool) {
        cardChromeColor = Color(uiColor: color)
        cardChromeIsDark = isDark
    }

    func bumpReplayRequest() {
        replayRequestID += 1
    }

    func bumpStopAudioRequest() {
        stopAudioRequestID += 1
    }

    func refreshAfterEdit() async {
        guard let queued = currentQueuedCard else { return }

        do {
            currentNote = try notes.getNote(queued.card.nid)
        } catch {
            print("[ReviewSession] refreshAfterEdit getNote failed: \(error)")
        }

        do {
            let rendered = try cardRendering.renderCard(queued.card.id)
            renderedFrontHTML = rendered.frontHTML
            renderedBackHTML = rendered.backHTML
            cardCSS = rendered.cardCSS

            typedAnswerState = resolveTypedAnswerState(for: queued, frontHTML: rendered.frontHTML)
            frontHTML = makeTypedAnswerFrontHTML(state: typedAnswerState, raw: renderedFrontHTML)

            if showAnswer, let state = typedAnswerState {
                // Re-substitute back placeholder with diff using empty typed value.
                // We don't have the user's original typed text after a sheet round-trip.
                backHTML = makeTypedAnswerBackHTML(state: state, typedAnswer: "")
            } else {
                backHTML = renderedBackHTML
            }
        } catch {
            print("[ReviewSession] refreshAfterEdit render failed: \(error)")
        }
    }

    // MARK: - Private: card advancement

    private func advanceToNextCard() {
        guard let next = cardQueue.first else {
            isFinished = true
            currentQueuedCard = nil
            currentNote = nil
            return
        }

        currentQueuedCard = next
        showAnswer = false
        reviewStartTime = .now
        nextIntervals = next.nextIntervals
        typedAnswerState = nil
        stopAudioRequestID += 1

        do {
            currentNote = try notes.getNote(next.card.nid)
        } catch {
            print("[ReviewSession] getNote failed: \(error)")
            currentNote = nil
        }

        do {
            let rendered = try cardRendering.renderCard(next.card.id)
            renderedFrontHTML = rendered.frontHTML
            renderedBackHTML = rendered.backHTML
            cardCSS = rendered.cardCSS

            typedAnswerState = resolveTypedAnswerState(for: next, frontHTML: rendered.frontHTML)
            frontHTML = makeTypedAnswerFrontHTML(state: typedAnswerState, raw: renderedFrontHTML)
            backHTML = renderedBackHTML  // back substitution happens at reveal
        } catch {
            print("[ReviewSession] Render failed for card \(next.card.id): \(error)")
            renderedFrontHTML = "<p>Error rendering card</p>"
            renderedBackHTML = "<p>Error rendering card</p>"
            cardCSS = ""
            frontHTML = renderedFrontHTML
            backHTML = renderedBackHTML
            typedAnswerState = nil
        }
    }

    // MARK: - Typed-answer state resolution

    private func resolveTypedAnswerState(
        for queued: QueuedReviewCard,
        frontHTML: String
    ) -> TypedAnswerState? {
        guard let placeholder = firstTypedAnswerPlaceholder(in: frontHTML) else {
            return nil
        }

        do {
            let noteRecord = try notes.getNote(queued.card.nid)

            // Fetch per-field font/size config via service (keeps backend access inside AnkiServices).
            let fields = try notetypes.getNotetypeFields(noteRecord.mid)

            guard let field = fields.first(where: { $0.name == placeholder.fieldName }) else {
                // Field name not found — typed answer with empty expected
                return TypedAnswerState(
                    placeholder: placeholder.rawToken,
                    expected: "",
                    combining: placeholder.combining,
                    fontName: "-apple-system",
                    fontSize: 18
                )
            }

            let fieldValues = noteRecord.flds.components(separatedBy: "\u{1f}")
            guard fieldValues.indices.contains(field.ordinal) else {
                return nil
            }

            var expected = fieldValues[field.ordinal]

            // Cloze typed-answer: extract the specific cloze ordinal's text
            if let clozeOrdinal = placeholder.clozeOrdinal {
                expected = try cardRendering.extractClozeForTyping(expected, clozeOrdinal)
            }

            return TypedAnswerState(
                placeholder: placeholder.rawToken,
                expected: expected,
                combining: placeholder.combining,
                fontName: field.fontName,
                fontSize: field.fontSize
            )
        } catch {
            print("[ReviewSession] Typed answer resolution failed for card \(queued.card.id): \(error)")
            return nil
        }
    }

    // MARK: - Typed-answer HTML generation

    private func makeTypedAnswerFrontHTML(state: TypedAnswerState?, raw: String) -> String {
        guard let state, raw.contains(state.placeholder) else {
            return strippingTypedAnswerPlaceholders(from: raw)
        }
        if state.expected.isEmpty {
            return raw.replacingOccurrences(of: state.placeholder, with: "")
        }
        let inputHTML = """
        <center>
        <input type="text" id="typeans" autocapitalize="none" autocomplete="off" autocorrect="off" spellcheck="false" onkeypress="return amgiHandleTypeAnswerKey(event);" style="font-family: '\(state.fontName)'; font-size: \(state.fontSize)px;">
        </center>
        """
        return raw.replacingOccurrences(of: state.placeholder, with: inputHTML)
    }

    private func makeTypedAnswerBackHTML(state: TypedAnswerState, typedAnswer: String) -> String {
        guard renderedBackHTML.contains(state.placeholder) else {
            return renderedBackHTML
        }
        if state.expected.isEmpty {
            return renderedBackHTML.replacingOccurrences(of: state.placeholder, with: "")
        }
        do {
            let diff = try cardRendering.compareAnswer(state.expected, typedAnswer, state.combining)
            let wrapped = "<div style=\"font-family: '\(state.fontName)'; font-size: \(state.fontSize)px\">\(diff)</div>"
            return renderedBackHTML.replacingOccurrences(of: state.placeholder, with: wrapped)
        } catch {
            print("[ReviewSession] compareAnswer failed: \(error)")
            return renderedBackHTML.replacingOccurrences(of: state.placeholder, with: "")
        }
    }

    private func strippingTypedAnswerPlaceholders(from html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\[\[type:.+?\]\]"#) else {
            return html
        }
        let range = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, range: range, withTemplate: "")
    }

    // MARK: - Placeholder parsing

    private struct TypedAnswerPlaceholder {
        let rawToken: String
        let fieldName: String
        let combining: Bool
        let clozeOrdinal: UInt32?
    }

    private func firstTypedAnswerPlaceholder(in html: String) -> TypedAnswerPlaceholder? {
        guard let regex = try? NSRegularExpression(pattern: #"\[\[type:(.+?)\]\]"#) else {
            return nil
        }
        let nsRange = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: nsRange),
              let rawRange = Range(match.range(at: 0), in: html),
              let specRange = Range(match.range(at: 1), in: html)
        else {
            return nil
        }

        var spec = String(html[specRange])
        var combining = true
        var clozeOrdinal: UInt32?

        if spec.hasPrefix("cloze:") {
            spec.removeFirst("cloze:".count)
            clozeOrdinal = queuedClozeOrdinal()
        }
        if spec.hasPrefix("nc:") {
            spec.removeFirst("nc:".count)
            combining = false
        }

        guard !spec.isEmpty else { return nil }

        return TypedAnswerPlaceholder(
            rawToken: String(html[rawRange]),
            fieldName: spec,
            combining: combining,
            clozeOrdinal: clozeOrdinal
        )
    }

    private func queuedClozeOrdinal() -> UInt32 {
        UInt32((currentQueuedCard?.card.ord ?? 0)) + 1
    }

    // MARK: - Typed-answer async read

    private func readTypedAnswerWithTimeout() async -> String? {
        // Suspend until JS calls submitTypedAnswer or 100 ms elapses.
        // We register our continuation on the MainActor, then launch a timeout
        // Task that also runs on MainActor and cancels if the continuation fires first.
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            // Store continuation — submitTypedAnswer will resume it
            typedAnswerContinuation = cont
            // Timeout: if the continuation is still pending after 100 ms, drain it with nil
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, self.typedAnswerContinuation != nil else { return }
                self.typedAnswerContinuation?.resume(returning: nil)
                self.typedAnswerContinuation = nil
            }
        }
    }
}
