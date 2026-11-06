//
//  ReviewSession.swift
//  ReviewCore
//
//  Created by Vladimir Gusev on 27.03.2026.
//

import OSLog
public import SwiftUI
import AppCore
#if canImport(UIKit)
import UIKit
#endif
public import AmgiCardWeb
import AnkiClients
public import AnkiKit
import AnkiServices
import Dependencies
import Foundation

public enum ResolvedRenderMode: Equatable, Sendable {
    case native(front: NativeCardContent, back: NativeCardContent)
    case html
}

/// How many cards the session asks the engine to gather at a time.
///
/// File scope rather than a static of the class: every gather happens inside a
/// `Task.detached`, and a MainActor-isolated static is not reachable from there.
private let queueFetchLimit: Int32 = 200

@Observable @MainActor
public final class ReviewSession {
    public let deckId: DeckID

    @ObservationIgnored @Dependency(\.decksService) var decks
    @ObservationIgnored @Dependency(\.schedulerService) var scheduler
    @ObservationIgnored @Dependency(\.cardRenderingService) var cardRendering
    @ObservationIgnored @Dependency(\.collectionService) var collection
    @ObservationIgnored @Dependency(\.notesService) var notes
    @ObservationIgnored @Dependency(\.notetypesService) var notetypes
    @ObservationIgnored @Dependency(\.notetypesClient) var notetypesClient

    public private(set) var frontHTML: String = ""
    public private(set) var backHTML: String = ""
    public private(set) var cardCSS: String = ""
    public private(set) var showAnswer: Bool = false
    public private(set) var sessionStats: SessionStats = .init()
    public private(set) var remainingCounts: DeckCounts = .zero
    public private(set) var deckName: String = ""
    public private(set) var isFinished: Bool = false
    public private(set) var canUndo: Bool = false
    public private(set) var nextIntervals: [Rating: String] = [:]
    public private(set) var replayRequestID: Int = 0       // plumbed; consumer is PR 1b
    public private(set) var stopAudioRequestID: Int = 0    // plumbed; consumer is PR 1b
    public private(set) var isAudioPlaying: Bool = false
    public private(set) var currentNote: NoteRecord?
    public private(set) var cardChromeColor: Color = .clear
    public private(set) var cardChromeIsDark: Bool = false
    public private(set) var resolvedMode: ResolvedRenderMode = .html
    public private(set) var resolvedByAuto: Bool = false
    public private(set) var templateName: String?
    public private(set) var answerTapCount: Int = 0
    public private(set) var tappedRating: Rating = .good
    public private(set) var undoneCount: Int = 0

    public private(set) var isAdvancing: Bool = false
    public var answerError: String?
    public private(set) var startError: String?
    /// A re-queue whose re-gather failed. Unlike a failed answer there is nothing
    /// to roll back: the card stays on screen and the counts stay where the
    /// engine last said they were. Surfaced, never swallowed.
    public var requeueError: String?
    /// What the last re-queue may tell the user, or nil when it may say nothing.
    public private(set) var studyNotice: StudyNotice?

    var reviewStartTime: ContinuousClock.Instant = .now
    var cardQueue: [QueuedReviewCard] = []
    var notetypeCache: [NotetypeID: Notetype] = [:]
    var currentQueuedCard: QueuedReviewCard?
    private var lastRating: Rating? = nil
    private var preparedNext: (id: CardID, card: PreparedCard)?
    @ObservationIgnored private var prefetchTask: Task<Void, Never>?
    private var studyNoticeSequence: Int = 0
    @ObservationIgnored private var studyNoticeDismissTask: Task<Void, Never>?
    /// A take-out asked for while a transition was in flight. The engine-side
    /// action has already landed, so the session's re-read waits for that
    /// transition rather than being dropped — see `finishTransition`.
    @ObservationIgnored private var pendingRequeue = false

    /// How long the take-out caption stays up: the same beat as the sync toast's
    /// success message, long enough to read and gone before it becomes chrome.
    private static let studyNoticeDisplay: Duration = .seconds(2)

    var renderedFrontHTML: String = ""
    var renderedBackHTML: String = ""
    var typedAnswerState: TypedAnswerState?
    public var typedAnswer: String = ""

    // MARK: - Computed

    public var isTypedAnswerCard: Bool {
        typedAnswerState?.expected.isEmpty == false
    }

    public var requiresTypedAnswerInput: Bool {
        isTypedAnswerCard && !showAnswer
    }

    public var currentCardOrdinal: UInt32 {
        UInt32(max(0, currentQueuedCard?.card.ord ?? 0))
    }

    public struct TemplateTarget: Identifiable, Equatable, Sendable {
        public let notetypeId: NotetypeID
        public let ordinal: Int

        public var id: String { "\(notetypeId.rawValue)-\(ordinal)" }
    }

    public var currentTemplateTarget: TemplateTarget? {
        guard let card = currentQueuedCard?.card, let note = currentNote else { return nil }
        return TemplateTarget(notetypeId: note.mid, ordinal: Int(card.ord))
    }

    public var currentCardId: CardID? {
        currentQueuedCard?.card.id
    }

    // MARK: - Session progress

    public var sessionTotal: Int {
        sessionStats.reviewed + remainingCounts.total
    }

    public var cardPosition: Int {
        min(sessionStats.reviewed + 1, max(sessionTotal, 1))
    }

    public var progressFraction: Double {
        sessionTotal > 0 ? Double(sessionStats.reviewed) / Double(sessionTotal) : 0
    }

    var currentFlag: UInt32 {
        UInt32(max(0, currentQueuedCard?.card.flags ?? 0)) & 0b111
    }

    @ObservationIgnored public private(set) lazy var mediaFolder: URL? = {
        @Dependency(\.mediaClient) var mediaClient
        return mediaClient.folderURL()
    }()

    // MARK: - Init

    public init(deckId: DeckID) {
        self.deckId = deckId
    }

    // MARK: - Public interface

    public func start() {
        guard !isAdvancing else { return }
        isAdvancing = true
        startError = nil
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
            defer { finishTransition() }
            do {
                let (queue, name) = try await Task.detached { () -> (QueuedCardsResult, String) in
                    try decks.setCurrentDeck(deckId)
                    let name = (try? decks.getCurrentDeck().name) ?? ""
                    return (try scheduler.getQueuedCards(queueFetchLimit), name)
                }.value
                deckName = name
                applyFreshGather(queue)
                Log.review.info("Started with \(self.cardQueue.count) cards, counts: new=\(queue.newCount) learn=\(queue.learningCount) review=\(queue.reviewCount)")
                await advanceToNextCard(notes: notes, notetypes: notetypes, notetypesClient: notetypesClient, cardRendering: cardRendering)
            } catch {
                // NOT isFinished: that is the "queue ran dry" state and drives
                // the congratulations surface plus a success haptic. A start
                // failure gets its own state and a retry.
                Log.review.error("Start failed: \(error)")
                startError = error.localizedDescription
            }
        }
    }

    /// Flips to the answer side immediately. For typed-answer cards the diff
    /// is computed off the main actor and substituted when it lands — the
    /// `compareAnswer` FFI call used to run inline here, blocking the main
    /// thread at the exact moment of the tap.
    public func revealAnswer() {
        guard !showAnswer else { return }
        backHTML = strippingTypedAnswerPlaceholders(from: renderedBackHTML)
        showAnswer = true

        guard let state = typedAnswerState else { return }
        let typed = typedAnswer
        let rendered = renderedBackHTML
        let cardRendering = self.cardRendering
        let cardId = currentCardId
        Task {
            let html = await Task.detached {
                typedAnswerBackHTML(
                    state: state,
                    typedAnswer: typed,
                    renderedBackHTML: rendered,
                    cardRendering: cardRendering
                )
            }.value
            // The card can advance while the diff is in flight; don't paste a
            // stale answer over the new card.
            guard cardId == currentCardId, showAnswer else { return }
            backHTML = html
        }
    }

    public func answer(rating: Rating) {
        guard !isAdvancing, let queued = currentQueuedCard else { return }
        isAdvancing = true

        // ContinuousClock, not Date: a backwards wall-clock adjustment
        // (NTP correction, manual change) mid-review made this negative,
        // and UInt32(negative) traps. Clamped as well, since a card left
        // open for ~49.7 days would overflow.
        let elapsed = reviewStartTime.duration(to: .now)
        let elapsedMs = elapsed.components.seconds * 1000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
        let timeSpent = UInt32(min(max(elapsedMs, 0), Int64(UInt32.max)))
        let cardId = queued.card.id
        let states = queued.states
        let scheduler = self.scheduler
        let notes = self.notes
        let notetypes = self.notetypes
        let notetypesClient = self.notetypesClient
        let cardRendering = self.cardRendering

        answerTapCount += 1
        tappedRating = rating

        // The interval brackets the whole tap-to-next-card wait, not the
        // synchronous prologue above: the scheduler round-trip and the
        // advance are what the user actually waits on.
        Task {
            defer { finishTransition() }
            await AppSignpost.measure("AnswerCard") {
                do {
                    let queue = try await Task.detached {
                        try scheduler.answerReviewCard(cardId, rating, timeSpent, states)
                        return try scheduler.getQueuedCards(queueFetchLimit)
                    }.value

                    answerError = nil
                    sessionStats.reviewed += 1
                    if rating != .again { sessionStats.correct += 1 }
                    sessionStats.totalTimeMs += Int(timeSpent)
                    lastRating = rating
                    canUndo = true

                    applyFreshGather(queue)
                    await advanceToNextCard(notes: notes, notetypes: notetypes, notetypesClient: notetypesClient, cardRendering: cardRendering)
                } catch {
                    // Do NOT drop the card. Silently removing it from the queue
                    // and advancing meant the review was never recorded, the
                    // card was skipped for the session, remainingCounts drifted
                    // permanently from the backend's, and the user saw an
                    // entirely normal advance.
                    Log.review.error("Answer failed: \(error)")
                    answerError = error.localizedDescription
                }
            }
        }
    }

    public func undo() {
        guard canUndo, !isAdvancing else { return }
        isAdvancing = true

        let collection = self.collection
        let scheduler = self.scheduler
        let notes = self.notes
        let notetypes = self.notetypes
        let notetypesClient = self.notetypesClient
        let cardRendering = self.cardRendering

        Task {
            defer { finishTransition() }
            do {
                let queue = try await Task.detached {
                    try collection.undoLast()
                    // Re-fetch queue — Anki places the undone card at the front
                    return try scheduler.getQueuedCards(queueFetchLimit)
                }.value

                canUndo = false
                undoneCount += 1
                // Roll back session stats only if the operation we just
                // undid was actually an answer. undoLast() undoes the last
                // *collection* operation, and a note edit is reachable from
                // this screen (refreshAfterEdit) — decrementing regardless
                // drove the counters below their true value, and negative.
                if let last = lastRating {
                    sessionStats.reviewed = max(0, sessionStats.reviewed - 1)
                    if last != .again {
                        sessionStats.correct = max(0, sessionStats.correct - 1)
                    }
                }
                lastRating = nil

                applyFreshGather(queue)
                await advanceToNextCard(notes: notes, notetypes: notetypes, notetypesClient: notetypesClient, cardRendering: cardRendering)
            } catch {
                Log.review.error("Undo failed: \(error)")
            }
        }
    }

    // MARK: - Re-queue

    /// A re-queue's claim about what left study, and the cue it warrants.
    /// How that claim is put into words is the study screen's business; this is
    /// only what the session can prove.
    ///
    /// Counted by identity — the ids in the queue snapshot that was thrown away,
    /// minus the ids the deck just handed back — never inferred from the totals.
    /// A card the deck still yields did not leave study, so "Forget Card" claims
    /// nothing. `id` rises with every claim, so a second take-out of the same
    /// size is still a new cue for the caption and its haptic.
    public struct StudyNotice: Equatable, Sendable {
        public let id: Int
        public let cardsTakenOutOfStudyCount: Int
    }

    /// What the session does after a card is taken out of study — suspended,
    /// buried, forgotten, deleted with its note, rescheduled past today: the queue
    /// it was working through is discarded rather than repaired, the remaining
    /// counts are read again, and study continues with whatever the deck yields
    /// next. If nothing is yielded the session is finished, which is the ordinary
    /// finished surface and not an error.
    ///
    /// Re-gathering is not caution, it is the only correct option: any card change
    /// but a flag clears the engine's own study queue, so this snapshot is already
    /// stale by the time the action returns. Splicing our own array instead is the
    /// drift `answer()`'s catch block describes.
    ///
    /// Grades nothing: `sessionStats` is untouched, so a card taken out of study is
    /// never counted as reviewed.
    public func requeueAfterCardRemoval() {
        // Deliberately not a way to start a session: with no card on screen
        // nothing was just taken out of study.
        guard currentQueuedCard != nil else { return }
        guard !isAdvancing else {
            // The card menu is not shut during a transition, so a take-out can
            // land mid-answer. The engine already has it; the session's re-read
            // waits its turn rather than being dropped, which is what would
            // leave the counts adrift until the next grade.
            pendingRequeue = true
            return
        }
        isAdvancing = true
        // The prefetch is rendering a card that has just left study. A typed-answer
        // diff already checks the card it was computed against before it lands, and
        // the advance below is what flips `showAnswer` off.
        invalidatePrefetch()

        let scheduler = self.scheduler
        let notes = self.notes
        let notetypes = self.notetypes
        let notetypesClient = self.notetypesClient
        let cardRendering = self.cardRendering
        let targetNoteId = currentQueuedCard?.card.nid

        // Identity snapshot of what this action could have touched. A card-menu
        // action aims at the card on screen or at its note, so only that note's
        // queued cards are candidates: a card of another note the fresh gather
        // no longer holds left for some other reason — a sync, another device —
        // and this session does not speak for it.
        let queuedIds = Set(
            cardQueue.filter { $0.card.nid == targetNoteId }.map { $0.card.id }
        )

        Task {
            defer { finishTransition() }
            do {
                let queue = try await Task.detached {
                    try scheduler.getQueuedCards(queueFetchLimit)
                }.value

                requeueError = nil
                applyFreshGather(queue)

                let gone = queuedIds.subtracting(queue.cards.map { $0.card.id }).count
                if gone > 0 {
                    studyNoticeSequence += 1
                    studyNotice = StudyNotice(
                        id: studyNoticeSequence,
                        cardsTakenOutOfStudyCount: gone
                    )
                    scheduleStudyNoticeDismiss()
                }

                await advanceToNextCard(notes: notes, notetypes: notetypes, notetypesClient: notetypesClient, cardRendering: cardRendering)
            } catch {
                // Honest, not silent. The card stays in front of the user, the
                // counts stay where the engine last said they were, and nothing is
                // claimed about a card we never got the chance to re-gather.
                Log.review.error("Re-queue failed: \(error)")
                requeueError = error.localizedDescription
            }
        }
    }

    public func updateAudioPlaying(_ playing: Bool) {
        isAudioPlaying = playing
    }

    public func updateCardChrome(color: Color, isDark: Bool) {
        cardChromeColor = color
        cardChromeIsDark = isDark
    }

    public func bumpReplayRequest() {
        replayRequestID += 1
    }

    public func bumpStopAudioRequest() {
        stopAudioRequestID += 1
    }

    /// Re-renders the current card after the note or template was edited.
    /// The whole engine round-trip runs off the main actor — it used to call
    /// `getNote` and `renderCard` inline, blocking the main thread while the
    /// edit sheet was dismissing.
    public func refreshAfterEdit() async {
        guard let queued = currentQueuedCard else { return }
        invalidatePrefetch()   // the edit may have changed a shared notetype

        let notes = self.notes
        let notetypes = self.notetypes
        let notetypesClient = self.notetypesClient
        let cardRendering = self.cardRendering
        let cache = notetypeCache
        let prepared = await Task.detached {
            await prepareCard(
                for: queued,
                notes: notes,
                notetypes: notetypes,
                cardRendering: cardRendering,
                notetypesClient: notetypesClient,
                notetypeCache: cache
            )
        }.value

        guard currentQueuedCard?.card.id == queued.card.id else { return }

        currentNote = prepared.note
        if let notetype = prepared.notetype {
            notetypeCache[notetype.id] = notetype
        }
        renderedFrontHTML = prepared.renderedFrontHTML
        renderedBackHTML = prepared.renderedBackHTML
        cardCSS = prepared.cardCSS
        typedAnswerState = prepared.typedAnswerState
        templateName = prepared.templateName
        frontHTML = prepared.frontHTML
        backHTML = strippingTypedAnswerPlaceholders(from: prepared.renderedBackHTML)
        reresolveCurrentCard()

        if showAnswer, let state = prepared.typedAnswerState {
            // Re-substitute the back placeholder with the diff; the typed text
            // survives the sheet round-trip in `typedAnswer`.
            let typed = typedAnswer
            let rendered = prepared.renderedBackHTML
            let html = await Task.detached {
                typedAnswerBackHTML(
                    state: state,
                    typedAnswer: typed,
                    renderedBackHTML: rendered,
                    cardRendering: cardRendering
                )
            }.value
            guard currentQueuedCard?.card.id == queued.card.id, showAnswer else { return }
            backHTML = html
        }
    }

    /// Re-runs render-mode resolution for the current card against the
    /// latest engine preference / overrides (RenderModeSheet writes).
    /// Cheap: reuses the already-rendered HTML.
    public func reresolveCurrentCard() {
        // The prefetched card was prepared against the *old* preferences.
        invalidatePrefetch()
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
    // MARK: - Private: transitions

    /// Clears the transition gate, then honours a take-out that asked while it
    /// was shut. Nothing may set `isAdvancing = false` on its own: a dropped
    /// re-queue is a session whose counts no longer match the deck's.
    func finishTransition() {
        isAdvancing = false
        if pendingRequeue {
            pendingRequeue = false
            requeueAfterCardRemoval()
        }
    }

    /// Assign a freshly gathered queue and the counts that came with it. Every
    /// path that changes a card goes through here; nothing edits `cardQueue` in
    /// place, because the engine has already thrown its own queue away.
    func applyFreshGather(_ queue: QueuedCardsResult) {
        cardQueue = queue.cards
        remainingCounts = DeckCounts(
            newCount: queue.newCount,
            learnCount: queue.learningCount,
            reviewCount: queue.reviewCount
        )
    }

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
            invalidatePrefetch()
            return
        }

        let prepared: PreparedCard
        if let hit = preparedNext, hit.id == next.card.id {
            prepared = hit.card
        } else {
            let cache = notetypeCache
            prepared = await Task.detached {
                await prepareCard(
                    for: next,
                    notes: notes,
                    notetypes: notetypes,
                    cardRendering: cardRendering,
                    notetypesClient: notetypesClient,
                    notetypeCache: cache
                )
            }.value
        }
        preparedNext = nil

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

        // Spend the user's reading time rendering the card after this one.
        prefetchFollowingCard(
            notes: notes,
            notetypes: notetypes,
            notetypesClient: notetypesClient,
            cardRendering: cardRendering
        )
    }

    // MARK: - Prefetch

    /// Renders the card after the current one while the user reads, into a
    /// single-slot cache. Speculative: the queue is re-fetched on every
    /// answer, so a learning card can resurface and change the head — a miss
    /// just costs the work we would have done anyway.
    func prefetchFollowingCard(
        notes: NotesService,
        notetypes: NotetypesService,
        notetypesClient: NotetypesClient,
        cardRendering: CardRenderingService
    ) {
        prefetchTask?.cancel()
        guard cardQueue.count > 1 else {
            preparedNext = nil
            return
        }
        let next = cardQueue[1]
        guard preparedNext?.id != next.card.id else { return }
        preparedNext = nil

        let cache = notetypeCache
        prefetchTask = Task { [weak self] in
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
            guard !Task.isCancelled else { return }
            self?.preparedNext = (id: next.card.id, card: prepared)
        }
    }

    func invalidatePrefetch() {
        prefetchTask?.cancel()
        prefetchTask = nil
        preparedNext = nil
    }

    /// The caption is acknowledgment, not a control: it says what happened and
    /// leaves. Cancelling first is what keeps a second take-out from being cut
    /// short by the first one's dismiss timer.
    func scheduleStudyNoticeDismiss() {
        studyNoticeDismissTask?.cancel()
        studyNoticeDismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.studyNoticeDisplay)
            guard !Task.isCancelled else { return }
            self?.studyNotice = nil
        }
    }

}

#if DEBUG
extension ReviewSession {
    /// Builds a session with canned display state for SwiftUI previews.
    /// Never calls `start()`, so it touches no backend — `ReviewContent`
    /// previews render the card or finished surface deterministically.
    /// Lives in this file so it can set the `private(set)` display state.
    /// Public because `ReviewContent`'s previews live in the app target.
    public static func preview(
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
