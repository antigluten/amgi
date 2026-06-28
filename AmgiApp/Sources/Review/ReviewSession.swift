import SwiftUI
import UIKit
import AnkiKit
import AnkiServices
import Dependencies
import Foundation

@Observable @MainActor
final class ReviewSession {
    let deckId: DeckID

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

    /// True while a card transition (start / answer / undo) has backend work
    /// in flight off the main actor. The view disables the answer + reveal
    /// buttons while set so a transition can't be re-entered mid-flight.
    private(set) var isAdvancing: Bool = false

    private var reviewStartTime: Date = .now
    private var cardQueue: [QueuedReviewCard] = []
    private var currentQueuedCard: QueuedReviewCard?
    private var lastRating: Rating? = nil

    // Typed-answer state
    private var renderedFrontHTML: String = ""
    private var renderedBackHTML: String = ""
    private var typedAnswerState: TypedAnswerState?
    private var typedAnswerContinuation: CheckedContinuation<String?, Never>?
    /// Monotonic token identifying the in-flight typed-answer read, so a
    /// stale timeout task can't drain a *later* cycle's continuation.
    private var typedAnswerGeneration: Int = 0

    // MARK: - Computed

    var requiresTypedAnswerInput: Bool {
        typedAnswerState != nil && !showAnswer
    }

    var currentCardOrdinal: UInt32 {
        UInt32(currentQueuedCard?.card.ord ?? 0)
    }

    struct TemplateTarget: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public let notetypeId: NotetypeID
        public let ordinal: Int

        public static func == (lhs: TemplateTarget, rhs: TemplateTarget) -> Bool {
            lhs.notetypeId == rhs.notetypeId && lhs.ordinal == rhs.ordinal
        }
    }

    var currentTemplateTarget: TemplateTarget? {
        guard let card = currentQueuedCard?.card, let note = currentNote else { return nil }
        return TemplateTarget(notetypeId: note.mid, ordinal: Int(card.ord))
    }

    var currentCardId: CardID? {
        currentQueuedCard?.card.id
    }

    /// Bottom 3 bits of the current card's flags field — the flag color
    /// index (0 = none, 1–7 = red/orange/green/blue/pink/cyan/purple).
    /// Mirrors the masking convention used by `cardClient.getCardFlags`.
    var currentFlag: UInt32 {
        UInt32(currentQueuedCard?.card.flags ?? 0) & 0b111
    }

    // MARK: - Init

    init(deckId: DeckID) {
        self.deckId = deckId
    }

    // MARK: - Public interface

    func start() {
        guard !isAdvancing else { return }
        isAdvancing = true
        // Resolve the Sendable service facades here, in the caller's
        // dependency scope, then hand them to the off-actor work.
        let decks = self.decks
        let scheduler = self.scheduler
        let notes = self.notes
        let notetypes = self.notetypes
        let cardRendering = self.cardRendering
        let deckId = self.deckId
        Task {
            defer { isAdvancing = false }
            do {
                let queue = try await Task.detached {
                    try decks.setCurrentDeck(deckId)
                    return try scheduler.getQueuedCards(200)
                }.value
                cardQueue = queue.cards
                remainingCounts = DeckCounts(
                    newCount: queue.newCount,
                    learnCount: queue.learningCount,
                    reviewCount: queue.reviewCount
                )
                print("[ReviewSession] Started with \(cardQueue.count) cards, counts: new=\(queue.newCount) learn=\(queue.learningCount) review=\(queue.reviewCount)")
                await advanceToNextCard(notes: notes, notetypes: notetypes, cardRendering: cardRendering)
            } catch {
                print("[ReviewSession] Start failed: \(error)")
                isFinished = true
            }
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
        guard !isAdvancing, let queued = currentQueuedCard else { return }
        isAdvancing = true

        let timeSpent = UInt32(Date.now.timeIntervalSince(reviewStartTime) * 1000)
        let cardId = queued.card.id
        let states = queued.states
        let scheduler = self.scheduler
        let notes = self.notes
        let notetypes = self.notetypes
        let cardRendering = self.cardRendering

        Task {
            defer { isAdvancing = false }
            do {
                let queue = try await Task.detached {
                    try scheduler.answerReviewCard(cardId, rating, timeSpent, states)
                    return try scheduler.getQueuedCards(200)
                }.value

                sessionStats.reviewed += 1
                if rating != .again { sessionStats.correct += 1 }
                sessionStats.totalTimeMs += Int(timeSpent)
                lastRating = rating
                canUndo = true

                cardQueue = queue.cards
                remainingCounts = DeckCounts(
                    newCount: queue.newCount,
                    learnCount: queue.learningCount,
                    reviewCount: queue.reviewCount
                )
                await advanceToNextCard(notes: notes, notetypes: notetypes, cardRendering: cardRendering)
            } catch {
                print("[ReviewSession] Answer failed: \(error)")
                if !cardQueue.isEmpty { cardQueue.removeFirst() }
                await advanceToNextCard(notes: notes, notetypes: notetypes, cardRendering: cardRendering)
            }
        }
    }

    func undo() {
        guard canUndo, !isAdvancing else { return }
        isAdvancing = true

        let collection = self.collection
        let scheduler = self.scheduler
        let notes = self.notes
        let notetypes = self.notetypes
        let cardRendering = self.cardRendering

        Task {
            defer { isAdvancing = false }
            do {
                let queue = try await Task.detached {
                    try collection.undoLast()
                    // Re-fetch queue — Anki places the undone card at the front
                    return try scheduler.getQueuedCards(200)
                }.value

                canUndo = false
                // Roll back session stats
                sessionStats.reviewed -= 1
                if let last = lastRating, last != .again {
                    sessionStats.correct -= 1
                }
                lastRating = nil

                cardQueue = queue.cards
                remainingCounts = DeckCounts(
                    newCount: queue.newCount,
                    learnCount: queue.learningCount,
                    reviewCount: queue.reviewCount
                )
                await advanceToNextCard(notes: notes, notetypes: notetypes, cardRendering: cardRendering)
            } catch {
                print("[ReviewSession] Undo failed: \(error)")
            }
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

            typedAnswerState = resolveTypedAnswerState(
                for: queued,
                frontHTML: rendered.frontHTML,
                notes: notes,
                notetypes: notetypes,
                cardRendering: cardRendering
            )
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
}

private extension ReviewSession {
    // MARK: - Private: card advancement

    /// Advances to the next queued card. Pops the queue on the main actor,
    /// then renders the card off the main actor via `Task.detached` and
    /// assigns the resulting state back here. The scheduler/queue mutation
    /// already happened in the caller; this only prepares display state.
    func advanceToNextCard(
        notes: NotesService,
        notetypes: NotetypesService,
        cardRendering: CardRenderingService
    ) async {
        guard let next = cardQueue.first else {
            isFinished = true
            currentQueuedCard = nil
            currentNote = nil
            return
        }

        let prepared = await Task.detached {
            prepareCard(for: next, notes: notes, notetypes: notetypes, cardRendering: cardRendering)
        }.value

        currentQueuedCard = next
        currentNote = prepared.note
        renderedFrontHTML = prepared.renderedFrontHTML
        renderedBackHTML = prepared.renderedBackHTML
        cardCSS = prepared.cardCSS
        typedAnswerState = prepared.typedAnswerState
        frontHTML = prepared.frontHTML
        backHTML = prepared.renderedBackHTML  // back substitution happens at reveal
        nextIntervals = next.nextIntervals
        showAnswer = false
        reviewStartTime = .now
        stopAudioRequestID += 1
    }

    // MARK: - Typed-answer HTML generation (main-actor side)

    func makeTypedAnswerBackHTML(state: TypedAnswerState, typedAnswer: String) -> String {
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

    // MARK: - Typed-answer async read

    func readTypedAnswerWithTimeout() async -> String? {
        // Suspend until JS calls submitTypedAnswer or 100 ms elapses.
        // The generation token guards against a stale timeout task draining
        // a continuation registered by a *later* reveal cycle.
        typedAnswerGeneration += 1
        let generation = typedAnswerGeneration
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            typedAnswerContinuation = cont
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
                guard let self,
                      self.typedAnswerGeneration == generation,
                      let pending = self.typedAnswerContinuation else { return }
                pending.resume(returning: nil)
                self.typedAnswerContinuation = nil
            }
        }
    }
}

// MARK: - Off-main card preparation
//
// These run inside `Task.detached`, so they are file-scope `nonisolated`
// functions that take the Sendable service facades explicitly rather than
// reaching through `self`. They produce a `Sendable PreparedCard` that
// `advanceToNextCard` assigns to `@Observable` state on the main actor.

/// Immutable, off-actor render result for one queued card.
private struct PreparedCard: Sendable {
    let note: NoteRecord?
    let renderedFrontHTML: String
    let renderedBackHTML: String
    let cardCSS: String
    let typedAnswerState: TypedAnswerState?
    let frontHTML: String
}

private struct TypedAnswerPlaceholder {
    let rawToken: String
    let fieldName: String
    let combining: Bool
    let clozeOrdinal: UInt32?
}

private func prepareCard(
    for queued: QueuedReviewCard,
    notes: NotesService,
    notetypes: NotetypesService,
    cardRendering: CardRenderingService
) -> PreparedCard {
    let note: NoteRecord?
    do {
        note = try notes.getNote(queued.card.nid)
    } catch {
        print("[ReviewSession] getNote failed: \(error)")
        note = nil
    }

    do {
        let rendered = try cardRendering.renderCard(queued.card.id)
        let typedState = resolveTypedAnswerState(
            for: queued,
            frontHTML: rendered.frontHTML,
            notes: notes,
            notetypes: notetypes,
            cardRendering: cardRendering
        )
        return PreparedCard(
            note: note,
            renderedFrontHTML: rendered.frontHTML,
            renderedBackHTML: rendered.backHTML,
            cardCSS: rendered.cardCSS,
            typedAnswerState: typedState,
            frontHTML: makeTypedAnswerFrontHTML(state: typedState, raw: rendered.frontHTML)
        )
    } catch {
        print("[ReviewSession] Render failed for card \(queued.card.id): \(error)")
        return PreparedCard(
            note: note,
            renderedFrontHTML: "<p>Error rendering card</p>",
            renderedBackHTML: "<p>Error rendering card</p>",
            cardCSS: "",
            typedAnswerState: nil,
            frontHTML: "<p>Error rendering card</p>"
        )
    }
}

// MARK: - Typed-answer state resolution

private func resolveTypedAnswerState(
    for queued: QueuedReviewCard,
    frontHTML: String,
    notes: NotesService,
    notetypes: NotetypesService,
    cardRendering: CardRenderingService
) -> TypedAnswerState? {
    guard let placeholder = firstTypedAnswerPlaceholder(
        in: frontHTML,
        cardOrdinal: UInt32(queued.card.ord)
    ) else {
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

// MARK: - Placeholder parsing

private func firstTypedAnswerPlaceholder(in html: String, cardOrdinal: UInt32) -> TypedAnswerPlaceholder? {
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
        clozeOrdinal = cardOrdinal + 1
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

private func strippingTypedAnswerPlaceholders(from html: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: #"\[\[type:.+?\]\]"#) else {
        return html
    }
    let range = NSRange(html.startIndex..., in: html)
    return regex.stringByReplacingMatches(in: html, range: range, withTemplate: "")
}

#if DEBUG
extension ReviewSession {
    /// Builds a session with canned display state for SwiftUI previews.
    /// Never calls `start()`, so it touches no backend — `ReviewContent`
    /// previews render the card or finished surface deterministically.
    /// Lives in this file so it can set the `private(set)` display state.
    static func preview(
        showAnswer: Bool = false,
        isFinished: Bool = false,
        front: String = "<div class=\"card\">猫</div>",
        back: String = "<div class=\"card\">猫<hr>cat — a small domesticated feline</div>",
        reviewed: Int = 7,
        counts: DeckCounts = DeckCounts(newCount: 5, learnCount: 2, reviewCount: 13)
    ) -> ReviewSession {
        let session = ReviewSession(deckId: DeckID(1))
        session.frontHTML = front
        session.backHTML = back
        session.cardCSS = """
        .card { font-family: -apple-system; font-size: 30px; text-align: center; padding: 24px; }
        hr { margin: 20px 0; border: none; border-top: 1px solid #ccc; }
        """
        session.showAnswer = showAnswer
        session.isFinished = isFinished
        session.sessionStats = SessionStats(reviewed: reviewed, correct: 6, totalTimeMs: 42_000)
        session.remainingCounts = counts
        session.nextIntervals = [.again: "<1m", .hard: "8m", .good: "1d", .easy: "4d"]
        session.canUndo = reviewed > 0
        return session
    }
}
#endif
