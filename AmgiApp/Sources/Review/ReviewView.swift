import SwiftUI
import AmgiCardWeb
import AmgiTheme
import AnkiBackend
import AnkiKit
import Dependencies
import Sharing

/// Container: owns the `ReviewSession`, the review preferences, the sheet
/// selection state, and the session lifecycle (`start()`, audio-session
/// application, widget snapshot on disappear). Hands the session plus pref
/// values and sheet bindings to the pure `ReviewContent`, which is what the
/// `#Preview`s build with a stub session.
struct ReviewView: View {
    let deckId: DeckID
    let onDismiss: () -> Void

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

    init(deckId: DeckID, onDismiss: @escaping () -> Void) {
        self.deckId = deckId
        self.onDismiss = onDismiss
        self._session = State(initialValue: ReviewSession(deckId: deckId))
    }

    var body: some View {
        ReviewContent(
            session: session,
            showRemainingDays: showRemainingDays,
            showAudioReplayButton: showAudioReplayButton,
            showContextMenuButton: showContextMenuButton,
            autoMatchCardBackground: autoMatchCardBackground,
            openLinksExternally: openLinksExternally,
            cardContentAlignment: cardContentAlignment,
            tapLookup: tapLookup,
            disperseAnswerButtons: disperseAnswerButtons,
            showNextReviewTime: showNextReviewTime,
            editingNote: $editingNote,
            editingTemplate: $editingTemplate,
            lookupQuery: $lookupQuery,
            onDismiss: onDismiss
        )
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
}

// MARK: - Content

/// Pure render surface for a review session: the card/finished views,
/// toolbar, and edit/lookup sheets. Takes the session read-only plus pref
/// values and sheet bindings — no lifecycle, so a `#Preview` renders it
/// with a stub session and no backend.
private struct ReviewContent: View {
    let session: ReviewSession
    let showRemainingDays: Bool
    let showAudioReplayButton: Bool
    let showContextMenuButton: Bool
    let autoMatchCardBackground: Bool
    let openLinksExternally: Bool
    let cardContentAlignment: String
    let tapLookup: Bool
    let disperseAnswerButtons: Bool
    let showNextReviewTime: Bool
    @Binding var editingNote: NoteRecord?
    @Binding var editingTemplate: ReviewSession.TemplateTarget?
    @Binding var lookupQuery: String?
    let onDismiss: () -> Void

    @Environment(\.palette) private var palette
    @State private var showRenderModeSheet = false
    @State private var nativeAudioPlayer = NativeCardAudioPlayer()

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
                    .accessibilityLabel("Undo")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingNote = session.currentNote
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .disabled(session.currentNote == nil)
                    .accessibilityLabel("Edit note")
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
                        .accessibilityLabel(session.isAudioPlaying ? "Stop audio" : "Replay audio")
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
                        .accessibilityLabel("Card options")
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
    }

    @ViewBuilder
    private var cardView: some View {
        VStack(spacing: 0) {
            RenderModeChipRow(
                isNative: isNativeMode,
                isAuto: session.resolvedByAuto,
                templateName: session.templateName,
                onTap: { showRenderModeSheet = true }
            )
            .padding(.horizontal)
            .padding(.vertical, 4)

            FlipContainer(showBack: session.showAnswer) { isBack in
                cardSurface(isBack: isBack)
            }
            .onChange(of: session.stopAudioRequestID) { _, _ in
                if isNativeMode { nativeAudioPlayer.stop() }
            }
            .onChange(of: session.currentCardId) { _, _ in playNativeAudio() }
            .onChange(of: session.showAnswer) { _, shown in
                if shown { playNativeAudio() }
            }
            .onChange(of: session.replayRequestID) { _, _ in playNativeAudio() }
            .onChange(of: nativeAudioPlayer.isPlaying) { _, playing in
                if isNativeMode { session.updateAudioPlaying(playing) }
            }
            .onDisappear { nativeAudioPlayer.stop() }
            .sheet(isPresented: $showRenderModeSheet) { renderModeSheet }

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
                .disabled(session.isAdvancing)
                .padding()
            }
        }
    }

    private var isNativeMode: Bool {
        if case .native = session.resolvedMode { return true }
        return false
    }

    private var renderModeSheet: some View {
        RenderModeSheet(
            explainer: renderModeExplainer,
            template: session.currentTemplateTarget,
            templateName: session.templateName,
            onChanged: { session.reresolveCurrentCard() }
        )
    }

    private var mediaFolder: URL? {
        @Dependency(\.ankiBackend) var backend
        guard let path = backend.currentMediaFolderPath else { return nil }
        return URL(fileURLWithPath: path)
    }

    private var renderModeExplainer: String {
        switch session.resolvedMode {
        case .native:
            return "rendered natively — passes the simplicity check."
        case .html:
            let prefs = currentRenderEnginePreferences(
                mid: session.currentNote?.mid,
                ord: Int(session.currentCardOrdinal)
            )
            if (prefs.override ?? prefs.global) == .alwaysHTML {
                return "rendered as HTML — selected for this card."
            }
            return "rendered as HTML — uses features the native renderer doesn't support."
        }
    }

    @ViewBuilder
    private func cardSurface(isBack: Bool) -> some View {
        switch session.resolvedMode {
        case .native(let front, let back):
            NativeCardView(
                content: isBack ? back : front,
                isAnswerSide: isBack,
                mediaFolder: mediaFolder
            )
        case .html:
            VStack(spacing: 0) {
                webChromeStrip
                CardWebView(
                    html: isBack ? session.backHTML : session.frontHTML,
                    cardCSS: session.cardCSS,
                    isAnswerSide: isBack,
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
            }
        }
    }

    /// Slim chrome above the sandboxed WebView card (R11): HTML badge ·
    /// template name · "sandboxed".
    private var webChromeStrip: some View {
        HStack(spacing: 8) {
            Text("HTML")
                .amgiFont(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(palette.warning)
            if let name = session.templateName {
                Text(name)
                    .font(.caption.monospaced())
                    .foregroundStyle(palette.textTertiary)
            }
            Spacer()
            Text("sandboxed")
                .amgiFont(.caption)
                .foregroundStyle(palette.textTertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private func playNativeAudio() {
        guard case .native(let front, let back) = session.resolvedMode else { return }
        let files = session.showAnswer ? back.audioFiles : front.audioFiles
        guard !files.isEmpty else { return }
        nativeAudioPlayer.play(files: files, mediaFolder: mediaFolder)
    }

    private var answerButtons: some View {
        HStack(spacing: disperseAnswerButtons ? 16 : 8) {
            ratingButton(.again, color: palette.danger)
            ratingButton(.hard, color: palette.warning)
            ratingButton(.good, color: palette.positive)
            ratingButton(.easy, color: palette.info)
        }
        .padding(.horizontal, disperseAnswerButtons ? 20 : 16)
        .padding(.vertical, 16)
    }

    private var finishedView: some View {
        VStack(spacing: AmgiSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(palette.positive)
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

private extension ReviewContent {
    func ratingButton(_ rating: Rating, color: Color) -> some View {
        Button {
            session.answer(rating: rating)
        } label: {
            VStack(spacing: 4) {
                if showNextReviewTime {
                    Text(session.nextIntervals[rating] ?? "")
                        .amgiFont(.caption)
                }
                Text(ratingLabel(rating))
                    .amgiFont(.bodyEmphasis)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(color)
        .disabled(session.isAdvancing)
    }

    func ratingLabel(_ rating: Rating) -> String {
        switch rating {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    func flagColor(for value: UInt32) -> Color {
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
}

/// Identifiable wrapper so `.sheet(item:)` can distinguish "not
/// presented" from "presented with empty query" — the toolbar button
/// opens the lookup popup focused on the search bar with no query yet.
private struct ReviewLookupQuery: Identifiable {
    let id = UUID()
    let text: String
}

// MARK: - Previews

#if DEBUG
#Preview("Question") {
    ReviewContent(
        session: .preview(showAnswer: false),
        showRemainingDays: true,
        showAudioReplayButton: true,
        showContextMenuButton: true,
        autoMatchCardBackground: false,
        openLinksExternally: true,
        cardContentAlignment: CardWebViewContentAlignment.center.rawValue,
        tapLookup: true,
        disperseAnswerButtons: false,
        showNextReviewTime: true,
        editingNote: .constant(nil),
        editingTemplate: .constant(nil),
        lookupQuery: .constant(nil),
        onDismiss: {}
    )
}

#Preview("Answer") {
    ReviewContent(
        session: .preview(showAnswer: true),
        showRemainingDays: true,
        showAudioReplayButton: true,
        showContextMenuButton: true,
        autoMatchCardBackground: false,
        openLinksExternally: true,
        cardContentAlignment: CardWebViewContentAlignment.center.rawValue,
        tapLookup: true,
        disperseAnswerButtons: false,
        showNextReviewTime: true,
        editingNote: .constant(nil),
        editingTemplate: .constant(nil),
        lookupQuery: .constant(nil),
        onDismiss: {}
    )
}

#Preview("Finished") {
    ReviewContent(
        session: .preview(isFinished: true),
        showRemainingDays: true,
        showAudioReplayButton: true,
        showContextMenuButton: true,
        autoMatchCardBackground: false,
        openLinksExternally: true,
        cardContentAlignment: CardWebViewContentAlignment.center.rawValue,
        tapLookup: true,
        disperseAnswerButtons: false,
        showNextReviewTime: true,
        editingNote: .constant(nil),
        editingTemplate: .constant(nil),
        lookupQuery: .constant(nil),
        onDismiss: {}
    )
}
#endif
