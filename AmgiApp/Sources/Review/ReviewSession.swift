import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import AmgiCardWeb
import AnkiClients
import AnkiKit
import AnkiServices
import Dependencies
import Foundation

/// How the current card is rendered (R11): parsed native content or the
/// sandboxed WebView. Resolved per card in `prepareCard`.
enum ResolvedRenderMode: Equatable {
    case native(front: NativeCardContent, back: NativeCardContent)
    case html
}

/// Feedback toast shown after rating a card ("Good · next in 10m") while the
/// next card is prepared (R11 answer flow).
struct RatingToast: Equatable {
    let rating: Rating
    let interval: String
}

@Observable @MainActor
final class ReviewSession {
    let deckId: DeckID

    @ObservationIgnored @Dependency(\.decksService) var decks
    @ObservationIgnored @Dependency(\.schedulerService) var scheduler
    @ObservationIgnored @Dependency(\.cardRenderingService) var cardRendering
    @ObservationIgnored @Dependency(\.collectionService) var collection
    @ObservationIgnored @Dependency(\.notesService) var notes
    @ObservationIgnored @Dependency(\.notetypesService) var notetypes
    @ObservationIgnored @Dependency(\.notetypesClient) var notetypesClient

    private(set) var frontHTML: String = ""
    private(set) var backHTML: String = ""
    private(set) var cardCSS: String = ""
    private(set) var showAnswer: Bool = false
    private(set) var sessionStats: SessionStats = .init()
    private(set) var remainingCounts: DeckCounts = .zero
    private(set) var deckName: String = ""
    private(set) var isFinished: Bool = false
    private(set) var canUndo: Bool = false
    private(set) var nextIntervals: [Rating: String] = [:]
    private(set) var replayRequestID: Int = 0       // plumbed; consumer is PR 1b
    private(set) var stopAudioRequestID: Int = 0    // plumbed; consumer is PR 1b
    private(set) var isAudioPlaying: Bool = false
    private(set) var currentNote: NoteRecord?
    private(set) var cardChromeColor: Color = .clear
    private(set) var cardChromeIsDark: Bool = false
    private(set) var resolvedMode: ResolvedRenderMode = .html
    private(set) var resolvedByAuto: Bool = false
    private(set) var templateName: String?
    private(set) var pendingToast: RatingToast?

    /// True while a card transition (start / answer / undo) has backend work
    /// in flight off the main actor. The view disables the answer + reveal
    /// buttons while set so a transition can't be re-entered mid-flight.
    private(set) var isAdvancing: Bool = false

    private var reviewStartTime: Date = .now
    private var cardQueue: [QueuedReviewCard] = []
    /// Full notetypes fetched for template names; keyed by notetype id and
    /// kept for the session so each notetype is fetched once.
    private var notetypeCache: [NotetypeID: Notetype] = [:]
    private var currentQueuedCard: QueuedReviewCard?
    private var lastRating: Rating? = nil

    // Typed-answer state
    private var renderedFrontHTML: String = ""
    private var renderedBackHTML: String = ""
    private var typedAnswerState: TypedAnswerState?
    /// Bound to the native typed-answer field in ReviewView. Native (not an
    /// in-card HTML input) so keyboard traits fully apply — the predictive
    /// bar would otherwise offer the answer as a suggestion.
    var typedAnswer: String = ""

    // MARK: - Computed

    var requiresTypedAnswerInput: Bool {
        typedAnswerState?.expected.isEmpty == false && !showAnswer
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
        let notetypesClient = self.notetypesClient
        let cardRendering = self.cardRendering
        let deckId = self.deckId
        Task {
            defer { isAdvancing = false }
            do {
                let (queue, name) = try await Task.detached { () -> (QueuedCardsResult, String) in
                    try decks.setCurrentDeck(deckId)
                    let name = (try? decks.getCurrentDeck().name) ?? ""
                    return (try scheduler.getQueuedCards(200), name)
                }.value
                cardQueue = queue.cards
                deckName = name
                remainingCounts = DeckCounts(
                    newCount: queue.newCount,
                    learnCount: queue.learningCount,
                    reviewCount: queue.reviewCount
                )
                print("[ReviewSession] Started with \(cardQueue.count) cards, counts: new=\(queue.newCount) learn=\(queue.learningCount) review=\(queue.reviewCount)")
                await advanceToNextCard(notes: notes, notetypes: notetypes, notetypesClient: notetypesClient, cardRendering: cardRendering)
            } catch {
                print("[ReviewSession] Start failed: \(error)")
                isFinished = true
            }
        }
    }

    func revealAnswer() {
        if let state = typedAnswerState {
            backHTML = makeTypedAnswerBackHTML(state: state, typedAnswer: typedAnswer)
        } else {
            backHTML = strippingTypedAnswerPlaceholders(from: renderedBackHTML)
        }
        showAnswer = true
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
        let notetypesClient = self.notetypesClient
        let cardRendering = self.cardRendering

        pendingToast = RatingToast(rating: rating, interval: queued.nextIntervals[rating] ?? "")

        Task {
            defer {
                isAdvancing = false
                pendingToast = nil
            }
            // The toast stays up at least this long; the next card appears
            // after max(backend round-trip, toast display).
            let minToastDisplay = Task { try? await Task.sleep(for: .milliseconds(450)) }
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
                await minToastDisplay.value
                await advanceToNextCard(notes: notes, notetypes: notetypes, notetypesClient: notetypesClient, cardRendering: cardRendering)
            } catch {
                print("[ReviewSession] Answer failed: \(error)")
                if !cardQueue.isEmpty { cardQueue.removeFirst() }
                await minToastDisplay.value
                await advanceToNextCard(notes: notes, notetypes: notetypes, notetypesClient: notetypesClient, cardRendering: cardRendering)
            }
        }
    }

    func undo() {
        guard canUndo, !isAdvancing else { return }
        isAdvancing = true
        pendingToast = nil

        let collection = self.collection
        let scheduler = self.scheduler
        let notes = self.notes
        let notetypes = self.notetypes
        let notetypesClient = self.notetypesClient
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
                await advanceToNextCard(notes: notes, notetypes: notetypes, notetypesClient: notetypesClient, cardRendering: cardRendering)
            } catch {
                print("[ReviewSession] Undo failed: \(error)")
            }
        }
    }

    func updateAudioPlaying(_ playing: Bool) {
        isAudioPlaying = playing
    }

#if canImport(UIKit)
    func updateCardChrome(color: UIColor, isDark: Bool) {
        cardChromeColor = Color(uiColor: color)
        cardChromeIsDark = isDark
    }
#endif

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
            frontHTML = strippingTypedAnswerPlaceholders(from: renderedFrontHTML)

            if showAnswer, let state = typedAnswerState {
                // Re-substitute back placeholder with the diff; the typed text
                // survives the sheet round-trip in `typedAnswer`.
                backHTML = makeTypedAnswerBackHTML(state: state, typedAnswer: typedAnswer)
            } else {
                backHTML = renderedBackHTML
            }
        } catch {
            print("[ReviewSession] refreshAfterEdit render failed: \(error)")
        }
        reresolveCurrentCard()
    }

    /// Re-runs render-mode resolution for the current card against the
    /// latest engine preference / overrides (RenderModeSheet writes).
    /// Cheap: reuses the already-rendered HTML.
    func reresolveCurrentCard() {
        guard let queued = currentQueuedCard else { return }
        let prefs = currentRenderEnginePreferences(mid: currentNote?.mid, ord: Int(queued.card.ord))
        let resolution = resolveRenderMode(
            renderedFront: renderedFrontHTML,
            renderedBack: renderedBackHTML,
            css: cardCSS,
            override: prefs.override,
            global: prefs.global
        )
        resolvedMode = resolution.mode
        resolvedByAuto = resolution.byAuto
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
        notetypesClient: NotetypesClient,
        cardRendering: CardRenderingService
    ) async {
        guard let next = cardQueue.first else {
            isFinished = true
            currentQueuedCard = nil
            currentNote = nil
            return
        }

        let cache = notetypeCache
        let prepared = await Task.detached {
            await prepareCard(
                for: next,
                notes: notes,
                notetypes: notetypes,
                cardRendering: cardRendering,
                notetypesClient: notetypesClient,
                notetypeCache: cache
            )
        }.value

        currentQueuedCard = next
        currentNote = prepared.note
        if let notetype = prepared.notetype {
            notetypeCache[notetype.id] = notetype
        }
        resolvedMode = prepared.resolvedMode
        resolvedByAuto = prepared.resolvedByAuto
        templateName = prepared.templateName
        renderedFrontHTML = prepared.renderedFrontHTML
        renderedBackHTML = prepared.renderedBackHTML
        cardCSS = prepared.cardCSS
        typedAnswerState = prepared.typedAnswerState
        typedAnswer = ""
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
    let resolvedMode: ResolvedRenderMode
    let resolvedByAuto: Bool
    let templateName: String?
    /// Freshly fetched notetype for the session cache; nil on cache hit
    /// or fetch failure.
    let notetype: Notetype?
}

/// Applies the R11 resolution order — template override → global preference
/// → complexity auto-detect — to one rendered card. `alwaysNative` still
/// yields `.html` when the card fails the simplicity check, so native
/// rendering is never lossy.
func resolveRenderMode(
    renderedFront: String,
    renderedBack: String,
    css: String,
    override: CardRenderEngine?,
    global: CardRenderEngine
) -> (mode: ResolvedRenderMode, byAuto: Bool) {
    let effective = override ?? global
    let simple = CardComplexity.isSimple(
        renderedFront: renderedFront,
        renderedBack: renderedBack,
        css: css
    )
    let wantNative = effective != .alwaysHTML && simple
    let mode: ResolvedRenderMode = wantNative
        ? .native(front: .parse(html: renderedFront), back: .parse(html: renderedBack))
        : .html
    return (mode, effective == .auto)
}

/// Reads the R11 engine preference + per-template override for one card.
/// UserDefaults is thread-safe, so this is callable from the off-actor
/// prepare path as well as main-actor re-resolution.
func currentRenderEnginePreferences(mid: NotetypeID?, ord: Int) -> (global: CardRenderEngine, override: CardRenderEngine?) {
    let defaults = UserDefaults.standard
    let global = defaults.string(forKey: ReviewPreferences.Keys.cardRenderEngine)
        .flatMap(CardRenderEngine.init(rawValue:)) ?? .auto
    let overridesRaw = defaults.string(forKey: ReviewPreferences.Keys.templateRenderOverrides) ?? "{}"
    let override = mid.flatMap { TemplateRenderOverrides.engine(for: $0, ord: ord, in: overridesRaw) }
    return (global, override)
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
    cardRendering: CardRenderingService,
    notetypesClient: NotetypesClient,
    notetypeCache: [NotetypeID: Notetype]
) async -> PreparedCard {
    let note: NoteRecord?
    do {
        note = try notes.getNote(queued.card.nid)
    } catch {
        print("[ReviewSession] getNote failed: \(error)")
        note = nil
    }

    // Template name comes from the full notetype (cached per session);
    // fetch failure only costs the chip-row label.
    var fetchedNotetype: Notetype?
    var templateName: String?
    if let mid = note?.mid {
        let notetype: Notetype?
        if let cached = notetypeCache[mid] {
            notetype = cached
        } else {
            fetchedNotetype = try? await notetypesClient.get(mid)
            notetype = fetchedNotetype
        }
        let ord = Int(queued.card.ord)
        if let notetype, notetype.templates.indices.contains(ord) {
            templateName = notetype.templates[ord].name
        }
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
        let prefs = currentRenderEnginePreferences(mid: note?.mid, ord: Int(queued.card.ord))
        let resolution = resolveRenderMode(
            renderedFront: rendered.frontHTML,
            renderedBack: rendered.backHTML,
            css: rendered.cardCSS,
            override: prefs.override,
            global: prefs.global
        )
        if case .html = resolution.mode {
            let issue = CardComplexity.complexityIssue(
                renderedFront: rendered.frontHTML,
                renderedBack: rendered.backHTML,
                css: rendered.cardCSS
            ) ?? "engine preference (global: \(prefs.global.rawValue), override: \(prefs.override?.rawValue ?? "none"))"
            print("[ReviewSession] card \(queued.card.id.rawValue) → HTML: \(issue); front=\(String(rendered.frontHTML.prefix(200)))")
        }
        return PreparedCard(
            note: note,
            renderedFrontHTML: rendered.frontHTML,
            renderedBackHTML: rendered.backHTML,
            cardCSS: rendered.cardCSS,
            typedAnswerState: typedState,
            frontHTML: strippingTypedAnswerPlaceholders(from: rendered.frontHTML),
            resolvedMode: resolution.mode,
            resolvedByAuto: resolution.byAuto,
            templateName: templateName,
            notetype: fetchedNotetype
        )
    } catch {
        print("[ReviewSession] Render failed for card \(queued.card.id): \(error)")
        return PreparedCard(
            note: note,
            renderedFrontHTML: "<p>Error rendering card</p>",
            renderedBackHTML: "<p>Error rendering card</p>",
            cardCSS: "",
            typedAnswerState: nil,
            frontHTML: "<p>Error rendering card</p>",
            resolvedMode: .html,
            resolvedByAuto: false,
            templateName: templateName,
            notetype: fetchedNotetype
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
        session.deckName = "한국어 · Vocab Typing"
        session.nextIntervals = [.again: "<1m", .hard: "8m", .good: "1d", .easy: "4d"]
        session.canUndo = reviewed > 0
        session.templateName = "Card 1"
        return session
    }
}
#endif
