//
//  ReviewCardArea.swift
//  ReviewFeature
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import SwiftUI
import AmgiCardWeb
import Theme
import UI
import AppCore
import AppShared
import AnkiClients
import AnkiKit
import Dependencies
import BrowseFeature
import TemplatesFeature
import Sharing
import ReviewCore
import SwiftUINavigation

// MARK: - Card Area

/// The card region of the reviewer: render-mode chip, the flip surface, and
/// the reveal/rating controls. Extracted from `ReviewContent` so that session
/// mutations it doesn't read (audio-playing toggles, toast, deck counts) skip
/// its body — otherwise every such change re-runs `CardWebView.updateUIView`
/// and its regex HTML processing. Owns the render-mode sheet flag and the
/// native audio player, which are only relevant here.
struct ReviewCardArea: View {
    let session: ReviewSession
    let openLinksExternally: Bool
    let cardContentAlignment: String
    let tapLookup: Bool
    let showNextReviewTime: Bool
    let lookupHighlight: LookupHighlight
    let shortcutsEnabled: Bool
    @Binding var lookupQuery: String?

    @Environment(\.palette) private var palette
    @Shared(.appStorage(ReaderPreferences.Keys.dictionaryScanLength))
    private var dictionaryScanLength: Int = 16
    @State private var showRenderModeSheet = false
    @State private var nativeAudioPlayer = NativeCardAudioPlayer()

    private var mediaFolder: URL? { session.mediaFolder }

    var body: some View {
        if session.currentCardId == nil {
            // No card prepared yet — `start()` is still in its backend round
            // trip. Rendering the normal chrome here meant an empty WKWebView
            // under a "HTML · sandboxed" label and a dead Show Answer button,
            // with nothing to say the app was working.
            preparingCard
        } else {
            cardContent
        }
    }

    private var preparingCard: some View {
        VStack(spacing: AmgiSpacing.md) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Preparing cards\u{2026}")
                .amgiFont(.body)
                .foregroundStyle(palette.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            RenderModeChipRow(
                isNative: isNativeMode,
                isAuto: session.resolvedByAuto,
                templateName: session.templateName,
                onTap: { showRenderModeSheet = true }
            )
            .padding(.horizontal)

            cardFlipRegion
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

            if session.isTypedAnswerCard {
                TypedAnswerField(session: session)
            }

            if session.showAnswer {
                answerButtons
            } else {
                Button {
                    session.revealAnswer()
                } label: {
                    Text("Show Answer")
                        .amgiFont(.bodyEmphasis)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(keyboardActive ? KeyboardShortcut(.space, modifiers: []) : nil)
                .padding()
            }
        }
        .animation(AmgiMotion.quick, value: session.showAnswer)
    }

    private var isNativeMode: Bool {
        if case .native = session.resolvedMode { return true }
        return false
    }

    private var keyboardActive: Bool {
        shortcutsEnabled && !showRenderModeSheet && !session.isTypedAnswerCard
    }

    /// The reveal region. Native cards get the 3D flip (pure SwiftUI, crisp);
    /// WebView cards swap sides without rotation, because 3D-rotating a live
    /// `WKWebView` rasterizes to a blurred frame mid-flip.
    @ViewBuilder
    private var cardFlipRegion: some View {
        if isNativeMode {
            FlipContainer(showBack: session.showAnswer) { isBack in
                cardSurface(isBack: isBack)
            }
        } else {
            cardSurface(isBack: session.showAnswer)
        }
    }

    private var renderModeSheet: some View {
        RenderModeSheet(
            explainer: renderModeExplainer,
            template: session.currentTemplateTarget,
            templateName: session.templateName,
            onChanged: { session.reresolveCurrentCard() }
        )
    }

    private var renderModeExplainer: String {
        switch session.resolvedMode {
        case .native:
            return "shown with the built-in renderer."
        case .html:
            let prefs = currentRenderEnginePreferences(
                mid: session.currentNote?.mid,
                ord: Int(session.currentCardOrdinal)
            )
            if (prefs.override ?? prefs.global) == .alwaysHTML {
                return "shown with its own template, because you chose that below."
            }
            return "shown with its own template, because it uses formatting the built-in renderer can't show."
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
                CardWebView(
                    html: isBack ? session.backHTML : session.frontHTML,
                    cardCSS: session.cardCSS,
                    isAnswerSide: isBack,
                    cardOrdinal: session.currentCardOrdinal,
                    replayRequestID: session.replayRequestID,
                    stopAudioRequestID: session.stopAudioRequestID,
                    openLinksExternally: openLinksExternally,
                    lookupPopupEnabled: tapLookup && !session.requiresTypedAnswerInput,
                    dictionaryScanLength: dictionaryScanLength,
                    lookupHighlight: lookupHighlight,
                    contentAlignment: CardWebViewContentAlignment(rawValue: cardContentAlignment) ?? .center,
                    onAudioStateChange: { playing in session.updateAudioPlaying(playing) },
                    onCardBackgroundColorChange: { color, isDark in
                        session.updateCardChrome(color: color, isDark: isDark)
                    },
                    // No tap-lookup while the typed-answer input is up — the
                    // dictionary would hand over the answer to be typed.
                    onLookupRequested: tapLookup && !session.requiresTypedAnswerInput ? { text, _, _ in
                        if let text, !text.isEmpty { lookupQuery = text }
                    } : nil,
                    onShowAnswerRequested: { session.revealAnswer() }
                )
            }
        }
    }


    private func playNativeAudio() {
        guard case .native(let front, let back) = session.resolvedMode else { return }
        let files = session.showAnswer ? back.audioFiles : front.audioFiles
        guard !files.isEmpty else { return }
        nativeAudioPlayer.play(files: files, mediaFolder: mediaFolder)
    }

    private var answerButtons: some View {
        RatingBar(
            intervals: session.nextIntervals,
            showIntervals: showNextReviewTime,
            isDisabled: session.isAdvancing,
            shortcutsEnabled: keyboardActive,
            onRate: { rating in session.answer(rating: rating) }
        )
    }
}

/// Native input for typed-answer (`{{type:}}`) cards. Native rather than an
/// in-card HTML input because WKWebView ignores web keyboard attributes and
/// the predictive bar would offer the answer as a suggestion.
struct TypedAnswerField: View {
    @Bindable var session: ReviewSession
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Type the answer", text: text)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.done)
            .onSubmit { session.revealAnswer() }
            .focused($focused)
            .padding(.horizontal)
            .onAppear { focused = true }
    }

    private var text: Binding<String> {
        Binding(
            get: { session.typedAnswer },
            set: { if !session.showAnswer { session.typedAnswer = $0 } }
        )
    }
}
