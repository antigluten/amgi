//
//  ReviewContent.swift
//  ReviewFeature
//
//  Created by Vladimir Gusev on 27.03.2026.
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

// MARK: - Content

/// Pure render surface for a review session: the card/finished views,
/// toolbar, and edit/lookup sheets. Takes the session read-only plus pref
/// values and sheet bindings — no lifecycle, so a `#Preview` renders it
/// with a stub session and no backend.
struct ReviewContent: View {
    let session: ReviewSession
    let showRemainingDays: Bool
    let autoMatchCardBackground: Bool
    let openLinksExternally: Bool
    let cardContentAlignment: String
    let tapLookup: Bool
    let showNextReviewTime: Bool
    @Binding var destination: ReviewDestination?
    let onDismiss: () -> Void

    @Environment(\.palette) private var palette
    /// Supplied by the app root — see `EnvironmentValues.lookupPopup`. Keeping
    /// the popup itself out of this target is what keeps it off the Cxx chain.
    @Environment(\.lookupPopup) private var lookupPopup
    @State private var cardActions = CardContextMenuModel()
    @State private var confirmDeleteNote = false
    @State private var lookupHighlight = LookupHighlight()

    private var keyboardActive: Bool {
        destination == nil && !confirmDeleteNote
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                #if !canImport(UIKit)
                macChrome
                #endif

                if showRemainingDays && session.startError == nil {
                    ReviewProgressBar(session: session)
                }

                if let startError = session.startError {
                    ReviewStartFailureView(message: startError) { session.start() }
                } else if session.isFinished {
                    ReviewFinishedView(session: session, onDone: onDismiss)
                } else {
                    ReviewCardArea(
                        session: session,
                        openLinksExternally: openLinksExternally,
                        cardContentAlignment: cardContentAlignment,
                        tapLookup: tapLookup,
                        showNextReviewTime: showNextReviewTime,
                        lookupHighlight: lookupHighlight,
                        shortcutsEnabled: keyboardActive,
                        lookupQuery: $destination.lookupText
                    )
                }
            }
            .background(palette.background)
            .reviewHaptics(session: session)
            .navigationBarTitleDisplayMode(.inline)
            #if canImport(UIKit)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .principal) {
                    ReviewDeckTitle(session: session)
                }
                if showRemainingDays {
                    ToolbarItem(placement: .topBarTrailing) {
                        ReviewPositionCounter(session: session)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ReviewUndoButton(session: session, shortcutEnabled: keyboardActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CardActionsMenu(
                        session: session,
                        cardActions: cardActions,
                        destination: $destination,
                        confirmDeleteNote: $confirmDeleteNote
                    )
                }
            }
            #endif
            .cardActionPresentations(
                model: cardActions,
                cardId: session.currentCardId,
                noteId: session.currentNote?.id,
                confirmDeleteNote: $confirmDeleteNote
            )
            #if canImport(UIKit)
            .cardChromeToolbar(session: session, enabled: autoMatchCardBackground)
            #endif
            .sheet(item: $destination.editNote) { note in
                NavigationStack {
                    NoteEditorView(note: note) {
                        Task { await session.refreshAfterEdit() }
                    }
                }
            }
            .sheet(item: $destination.editTemplate) { target in
                NavigationStack {
                    TemplateEditorView(
                        notetypeId: target.notetypeId,
                        initialTemplateIndex: target.ordinal,
                        mode: .currentCard,
                        onSaved: { await session.refreshAfterEdit() }
                    )
                }
            }
            .sheet(isPresented: Binding($destination.lookup), onDismiss: { lookupHighlight.clear() }) {
                if let lookupPopup {
                    lookupPopup.popup(
                        query: destination.lookupText ?? "",
                        onMatched: { lookupHighlight.show(matched: $0) },
                        onDismiss: { destination = nil }
                    )
                }
            }
        }
    }

    #if !canImport(UIKit)
    @ViewBuilder
    private var macChrome: some View {
        HStack(spacing: 12) {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")

            Spacer()
            ReviewDeckTitle(session: session)
            Spacer()

            if showRemainingDays {
                ReviewPositionCounter(session: session)
            }
            ReviewUndoButton(session: session, shortcutEnabled: keyboardActive)
            CardActionsMenu(
                session: session,
                cardActions: cardActions,
                destination: $destination,
                confirmDeleteNote: $confirmDeleteNote
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(palette.surface)

        Divider()
    }
    #endif
}

// MARK: - Toolbar chrome

private struct CardChromeToolbar: ViewModifier {
    let session: ReviewSession
    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .toolbarBackground(
                enabled ? session.cardChromeColor : Color.clear,
                for: .navigationBar
            )
            .toolbarBackground(
                enabled ? .visible : .automatic,
                for: .navigationBar
            )
            .toolbarColorScheme(
                enabled && session.cardChromeIsDark ? .dark : .light,
                for: .navigationBar
            )
    }
}

private struct ReviewHaptics: ViewModifier {
    let session: ReviewSession

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(trigger: session.answerTapCount) { _, _ in
                session.tappedRating == .again
                    ? .impact(weight: .medium)
                    : .impact(weight: .light)
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: session.undoneCount)
            .sensoryFeedback(trigger: session.isFinished) { _, finished in
                finished ? .success : nil
            }
    }
}

private extension View {
    func cardChromeToolbar(session: ReviewSession, enabled: Bool) -> some View {
        modifier(CardChromeToolbar(session: session, enabled: enabled))
    }

    func reviewHaptics(session: ReviewSession) -> some View {
        modifier(ReviewHaptics(session: session))
    }
}

// MARK: - Toolbar items

private struct ReviewDeckTitle: View {
    let session: ReviewSession

    @Environment(\.palette) private var palette

    var body: some View {
        Text(session.deckName)
            .amgiFont(.bodyEmphasis)
            .foregroundStyle(palette.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct ReviewPositionCounter: View {
    let session: ReviewSession

    @Environment(\.palette) private var palette

    var body: some View {
        let position = session.cardPosition
        let total = max(session.sessionTotal, 1)
        Text("\(position)/\(total)")
            .amgiFont(.caption)
            .monospacedDigit()
            .foregroundStyle(palette.textSecondary)
            .contentTransition(.numericText())
            .animation(AmgiMotion.quick, value: position)
            .accessibilityLabel("Card \(position) of \(total)")
    }
}

private struct ReviewUndoButton: View {
    let session: ReviewSession
    let shortcutEnabled: Bool

    var body: some View {
        Button {
            session.undo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .disabled(!session.canUndo)
        .keyboardShortcut(shortcutEnabled ? KeyboardShortcut("z", modifiers: .command) : nil)
        .accessibilityLabel("Undo")
    }
}

// MARK: - Card actions

private struct CardActionsMenu: View {
    let session: ReviewSession
    let cardActions: CardContextMenuModel
    @Binding var destination: ReviewDestination?
    @Binding var confirmDeleteNote: Bool

    @Environment(\.palette) private var palette

    var body: some View {
        Menu {
            if let cardId = session.currentCardId {
                CardFlagPicker(model: cardActions, cardId: cardId)
            }

            Section {
                Button {
                    destination = session.currentNote.map(ReviewDestination.editNote)
                } label: {
                    Label("Edit Note", systemImage: "pencil")
                }
                .disabled(session.currentNote == nil)

                Button {
                    destination = session.currentTemplateTarget.map(ReviewDestination.editTemplate)
                } label: {
                    Label("Edit Template", systemImage: "square.and.pencil")
                }
                .disabled(session.currentTemplateTarget == nil)

                Button {
                    // Empty initial query opens the popup focused for typing.
                    // Future enhancement: forward CardWebView text-selection so
                    // the query is pre-populated.
                    destination = .lookup("")
                } label: {
                    Label("Look Up", systemImage: "character.book.closed")
                }

                Button {
                    if session.isAudioPlaying {
                        session.bumpStopAudioRequest()
                    } else {
                        session.bumpReplayRequest()
                    }
                } label: {
                    Label(
                        session.isAudioPlaying ? "Stop Audio" : "Replay Audio",
                        systemImage: session.isAudioPlaying ? "pause.circle" : "play.circle"
                    )
                }
                .disabled(session.currentNote == nil)
            }

            if let cardId = session.currentCardId {
                CardActionSections(
                    model: cardActions,
                    cardId: cardId,
                    noteId: session.currentNote?.id,
                    confirmDeleteNote: $confirmDeleteNote
                )
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(
                    cardActions.currentFlag == 0
                        ? palette.accent
                        : CardFlag.color(cardActions.currentFlag)
                )
        }
        .accessibilityLabel("Card actions")
    }
}

// MARK: - Progress

private struct ReviewProgressBar: View {
    let session: ReviewSession

    @Environment(\.palette) private var palette

    var body: some View {
        let fraction = min(max(session.progressFraction, 0), 1)
        ZStack(alignment: .leading) {
            Capsule().fill(palette.separator)
            Capsule()
                .fill(palette.accent)
                .scaleEffect(x: fraction, y: 1, anchor: .leading)
        }
        .frame(height: 3)
        .padding(.horizontal)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .animation(AmgiMotion.standard, value: fraction)
    }
}

// MARK: - Terminal states

private struct ReviewStartFailureView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't Start Reviewing", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: onRetry)
                .buttonStyle(AmgiPrimaryButtonStyle())
        }
    }
}

private struct ReviewFinishedView: View {
    let session: ReviewSession
    let onDone: () -> Void

    @Environment(\.palette) private var palette
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 64

    var body: some View {
        VStack(spacing: AmgiSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: glyphSize))
                .foregroundStyle(palette.positive)
                .accessibilityHidden(true)   // "Congratulations!" below says it
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
            Button("Done", action: onDone)
                .buttonStyle(AmgiPrimaryButtonStyle())
                .padding()
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Question") {
    ReviewContent(
        session: .preview(showAnswer: false),
        showRemainingDays: true,
        autoMatchCardBackground: false,
        openLinksExternally: true,
        cardContentAlignment: CardWebViewContentAlignment.center.rawValue,
        tapLookup: true,
        showNextReviewTime: true,
        destination: .constant(nil),
        onDismiss: {}
    )
}

#Preview("Answer") {
    ReviewContent(
        session: .preview(showAnswer: true),
        showRemainingDays: true,
        autoMatchCardBackground: false,
        openLinksExternally: true,
        cardContentAlignment: CardWebViewContentAlignment.center.rawValue,
        tapLookup: true,
        showNextReviewTime: true,
        destination: .constant(nil),
        onDismiss: {}
    )
}

#Preview("Finished") {
    ReviewContent(
        session: .preview(isFinished: true),
        showRemainingDays: true,
        autoMatchCardBackground: false,
        openLinksExternally: true,
        cardContentAlignment: CardWebViewContentAlignment.center.rawValue,
        tapLookup: true,
        showNextReviewTime: true,
        destination: .constant(nil),
        onDismiss: {}
    )
}
#endif
