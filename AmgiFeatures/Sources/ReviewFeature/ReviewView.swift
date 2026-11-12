//
//  ReviewView.swift
//  ReviewFeature
//
//  Created by Vladimir Gusev on 27.03.2026.
//

package import SwiftUI
import AmgiCardWeb
import Theme
import UI
import AppCore
import AppShared
import AnkiClients
package import AnkiKit
import Dependencies
import BrowseFeature
import TemplatesFeature
import Sharing
import ReviewCore
import SwiftUINavigation


/// Container: owns the `ReviewSession`, the review preferences, the sheet
/// selection state, and the session lifecycle (`start()`, audio-session
/// application, widget snapshot on disappear). Hands the session plus pref
/// values and sheet bindings to the pure `ReviewContent`, which is what the
/// `#Preview`s build with a stub session.
package struct ReviewView: View {
    let deckId: DeckID
    let onDismiss: () -> Void

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

    @Shared(.appStorage(ReaderPreferences.Keys.tapLookup))
    private var tapLookup: Bool = true

    @Shared(.appStorage(ReviewPreferences.Keys.playAudioInSilentMode))
    private var playAudioInSilentMode: Bool = false

    @State private var session: ReviewSession
    @State private var destination: ReviewDestination?

    package init(deckId: DeckID, onDismiss: @escaping () -> Void) {
        self.deckId = deckId
        self.onDismiss = onDismiss
        self._session = State(initialValue: ReviewSession(deckId: deckId))
    }

    package var body: some View {
        ReviewContent(
            session: session,
            showRemainingDays: showRemainingDays,
            autoMatchCardBackground: autoMatchCardBackground,
            openLinksExternally: openLinksExternally,
            cardContentAlignment: cardContentAlignment,
            tapLookup: tapLookup,
            showNextReviewTime: showNextReviewTime,
            destination: $destination,
            onDismiss: onDismiss
        )
        .task {
            ReviewAudioSession.apply(playInSilent: playAudioInSilentMode)
            session.start()
        }
        .reviewSessionAlert("Couldn't save that review", \ReviewSession.answerError, in: session)
        // The card-menu action itself did land in the collection; what failed was
        // reading the deck back, so the card stays on screen and the session keeps
        // its last known counts. `start()`'s failure is not here: that gets its own
        // retry surface in `ReviewContent`, because a failure is not a finished deck.
        .reviewSessionAlert("Couldn't update the session", \ReviewSession.requeueError, in: session)
        .onChange(of: playAudioInSilentMode) { _, newValue in
            ReviewAudioSession.apply(playInSilent: newValue)
        }
        .onDisappear {
            ReviewAudioSession.release()
            Task { await writeWidgetSnapshot() }
        }
    }
}

// MARK: - Session failure alerts

private extension View {
    /// One alert per session error channel: the title names the act that failed,
    /// the body is the engine's own words.
    func reviewSessionAlert(
        _ title: String,
        _ channel: ReferenceWritableKeyPath<ReviewSession, String?>,
        in session: ReviewSession
    ) -> some View {
        modifier(ReviewSessionErrorAlert(title: title, channel: channel, session: session))
    }
}

private struct ReviewSessionErrorAlert: ViewModifier {
    let title: String
    let channel: ReferenceWritableKeyPath<ReviewSession, String?>
    let session: ReviewSession

    func body(content: Content) -> some View {
        content
            .alert(
                title,
                isPresented: Binding(
                    get: { session[keyPath: channel] != nil },
                    set: { if !$0 { session[keyPath: channel] = nil } }
                )
            ) {
                Button("OK", role: .cancel) { session[keyPath: channel] = nil }
            } message: {
                Text(session[keyPath: channel] ?? "")
            }
    }
}
