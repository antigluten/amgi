import SwiftUI
import AmgiTheme
import AnkiKit
import Sharing

struct ReviewView: View {
    let deckId: Int64
    let onDismiss: () -> Void

    @Environment(\.palette) private var palette

    @Shared(.appStorage(ReviewPreferences.Keys.showAudioReplayButton))
    private var showAudioReplayButton: Bool = true

    @Shared(.appStorage(ReviewPreferences.Keys.showContextMenuButton))
    private var showContextMenuButton: Bool = true

    @Shared(.appStorage(ReviewPreferences.Keys.openLinksExternally))
    private var openLinksExternally: Bool = true

    @Shared(.appStorage(ReviewPreferences.Keys.cardContentAlignment))
    private var cardContentAlignment: String = CardWebViewContentAlignment.center.rawValue

    @Shared(.appStorage(ReviewPreferences.Keys.autoMatchCardBackground))
    private var autoMatchCardBackground: Bool = true

    @Shared(.appStorage(ReviewPreferences.Keys.showRemainingDays))
    private var showRemainingDays: Bool = true

    @Shared(.appStorage(ReviewPreferences.Keys.showNextReviewTime))
    private var showNextReviewTime: Bool = true

    @Shared(.appStorage(ReviewPreferences.Keys.disperseAnswerButtons))
    private var disperseAnswerButtons: Bool = false

    @Shared(.appStorage(ReaderPreferences.Keys.tapLookup))
    private var tapLookup: Bool = true

    @Shared(.appStorage(ReviewPreferences.Keys.playAudioInSilentMode))
    private var playAudioInSilentMode: Bool = false

    @State private var session: ReviewSession
    @State private var editingNote: NoteRecord?
    @State private var editingTemplate: ReviewSession.TemplateTarget?
    @State private var lookupQuery: String?

    init(deckId: Int64, onDismiss: @escaping () -> Void) {
        self.deckId = deckId
        self.onDismiss = onDismiss
        self._session = State(initialValue: ReviewSession(deckId: deckId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showRemainingDays {
                    HStack(spacing: 12) {
                        DeckCountsView(counts: session.remainingCounts)
                        Spacer()
                        Text("\(session.sessionStats.reviewed) reviewed")
                            .amgiFont(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if session.isFinished {
                    finishedView
                } else {
                    cardView
                }
            }
            .background(palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { onDismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!session.canUndo)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingNote = session.currentNote
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .disabled(session.currentNote == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Empty initial query opens the popup focused
                        // for typing. Future enhancement: forward
                        // CardWebView text-selection so the query is
                        // pre-populated.
                        lookupQuery = ""
                    } label: {
                        Image(systemName: "character.book.closed")
                    }
                    .accessibilityLabel("Look up word")
                }
                if showAudioReplayButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if session.isAudioPlaying {
                                session.bumpStopAudioRequest()
                            } else {
                                session.bumpReplayRequest()
                            }
                        } label: {
                            Image(systemName: session.isAudioPlaying ? "pause.circle" : "play.circle")
                        }
                        .disabled(session.currentNote == nil)
                    }
                }
                if showContextMenuButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if let cardId = session.currentCardId {
                                CardContextMenu(cardId: cardId, noteId: session.currentNote?.id)
                            }
                            Divider()
                            Button {
                                editingTemplate = session.currentTemplateTarget
                            } label: {
                                Label("Edit Template", systemImage: "square.and.pencil")
                            }
                            .disabled(session.currentTemplateTarget == nil)
                        } label: {
                            if session.currentFlag != 0 {
                                Image(systemName: "flag.fill")
                                    .foregroundStyle(flagColor(for: session.currentFlag))
                            } else {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                        .disabled(session.currentNote == nil)
                    }
                }
            }
            .toolbarBackground(
                autoMatchCardBackground ? session.cardChromeColor : Color.clear,
                for: .navigationBar
            )
            .toolbarBackground(
                autoMatchCardBackground ? .visible : .automatic,
                for: .navigationBar
            )
            .toolbarColorScheme(
                autoMatchCardBackground && session.cardChromeIsDark ? .dark : .light,
                for: .navigationBar
            )
            .sheet(item: $editingNote) { note in
                NavigationStack {
                    NoteEditorView(note: note) {
                        Task { await session.refreshAfterEdit() }
                    }
                }
            }
            .sheet(item: $editingTemplate) { target in
                NavigationStack {
                    TemplateEditorView(
                        notetypeId: target.notetypeId,
                        initialTemplateIndex: target.ordinal,
                        mode: .currentCard,
                        onSaved: { await session.refreshAfterEdit() }
                    )
                }
            }
            .sheet(item: Binding(
                get: { lookupQuery.map(ReviewLookupQuery.init) },
                set: { lookupQuery = $0?.text }
            )) { wrapped in
                LookupPopupView(initialQuery: wrapped.text) {
                    lookupQuery = nil
                }
            }
        }
        .task {
            ReviewAudioSession.apply(playInSilent: playAudioInSilentMode)
            session.start()
        }
        .onChange(of: playAudioInSilentMode) { _, newValue in
            ReviewAudioSession.apply(playInSilent: newValue)
        }
        .onDisappear {
            Task { await writeWidgetSnapshot() }
        }
    }

    @ViewBuilder
    private var cardView: some View {
        VStack(spacing: 0) {
            CardWebView(
                html: session.showAnswer ? session.backHTML : session.frontHTML,
                cardCSS: session.cardCSS,
                isAnswerSide: session.showAnswer,
                cardOrdinal: session.currentCardOrdinal,
                replayRequestID: session.replayRequestID,
                stopAudioRequestID: session.stopAudioRequestID,
                typedAnswerRequestID: session.typedAnswerRequestID,
                openLinksExternally: openLinksExternally,
                contentAlignment: CardWebViewContentAlignment(rawValue: cardContentAlignment) ?? .center,
                onTypedAnswerSubmitted: { typed in session.submitTypedAnswer(typed) },
                onAudioStateChange: { playing in session.updateAudioPlaying(playing) },
                onCardBackgroundColorChange: { color, isDark in
                    session.updateCardChrome(color: color, isDark: isDark)
                },
                onLookupRequested: tapLookup ? { text, _, _ in
                    if let text, !text.isEmpty { lookupQuery = text }
                } : nil
            )

            Spacer()

            if session.showAnswer {
                answerButtons
            } else {
                Button {
                    Task { await session.revealAnswer() }
                } label: {
                    Text("Show Answer")
                        .amgiFont(.bodyEmphasis)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
    }

    private var answerButtons: some View {
        HStack(spacing: disperseAnswerButtons ? 16 : 8) {
            ratingButton(.again, color: .red)
            ratingButton(.hard, color: .orange)
            ratingButton(.good, color: .green)
            ratingButton(.easy, color: .blue)
        }
        .padding(.horizontal, disperseAnswerButtons ? 20 : 16)
        .padding(.vertical, 16)
    }

    private func ratingButton(_ rating: Rating, color: Color) -> some View {
        Button {
            session.answer(rating: rating)
        } label: {
            VStack(spacing: 4) {
                if showNextReviewTime {
                    Text(session.nextIntervals[rating] ?? "")
                        .font(.caption2)
                }
                Text(ratingLabel(rating))
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }

    private func ratingLabel(_ rating: Rating) -> String {
        switch rating {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    private func flagColor(for value: UInt32) -> Color {
        switch value & 0b111 {
        case 1: return .red
        case 2: return .orange
        case 3: return .green
        case 4: return .blue
        case 5: return .pink
        case 6: return .cyan
        case 7: return .purple
        default: return .secondary
        }
    }

    private func formatInterval(_ days: Int) -> String {
        if days == 0 { return "<1d" }
        if days < 30 { return "\(days)d" }
        if days < 365 { return "\(days / 30)mo" }
        return String(format: "%.1fy", Double(days) / 365.0)
    }

    private var finishedView: some View {
        VStack(spacing: AmgiSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Congratulations!")
                .amgiFont(.sectionHeading)
                .foregroundStyle(palette.textPrimary)
            Text("You've reviewed \(session.sessionStats.reviewed) cards")
                .amgiFont(.body)
                .foregroundStyle(palette.textSecondary)
            if session.sessionStats.reviewed > 0 {
                Text("Accuracy: \(Int(session.sessionStats.accuracy * 100))%")
                    .amgiFont(.body)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
            Button("Done") { onDismiss() }
                .buttonStyle(AmgiPrimaryButtonStyle())
                .padding()
        }
    }
}

/// Identifiable wrapper so `.sheet(item:)` can distinguish "not
/// presented" from "presented with empty query" — the toolbar button
/// opens the lookup popup focused on the search bar with no query yet.
private struct ReviewLookupQuery: Identifiable {
    let id = UUID()
    let text: String
}
