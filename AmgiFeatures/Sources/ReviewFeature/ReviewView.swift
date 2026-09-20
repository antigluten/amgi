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
        .alert(
            "Couldn't save that review",
            isPresented: Binding(
                get: { session.answerError != nil },
                set: { if !$0 { session.answerError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { session.answerError = nil }
        } message: {
            Text(session.answerError ?? "")
        }
        .onChange(of: playAudioInSilentMode) { _, newValue in
            ReviewAudioSession.apply(playInSilent: newValue)
        }
        .onDisappear {
            ReviewAudioSession.release()
            Task { await writeWidgetSnapshot() }
        }
    }
}
