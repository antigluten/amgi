import SwiftUI
import Sharing

struct ReviewSettingsView: View {
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

    @Shared(.appStorage(ReviewPreferences.Keys.playAudioInSilentMode))
    private var playAudioInSilentMode: Bool = false

    var body: some View {
        Form {
            Section("Toolbar") {
                Toggle("Show audio replay button", isOn: Binding($showAudioReplayButton))
                Toggle("Show context menu", isOn: Binding($showContextMenuButton))
            }

            Section("Card Display") {
                Toggle("Match toolbar to card background", isOn: Binding($autoMatchCardBackground))
                Toggle("Open links externally", isOn: Binding($openLinksExternally))
                Picker("Content alignment", selection: Binding($cardContentAlignment)) {
                    Text("Center").tag(CardWebViewContentAlignment.center.rawValue)
                    Text("Top").tag(CardWebViewContentAlignment.top.rawValue)
                }
            }

            Section("Answer Buttons") {
                Toggle("Show remaining counts", isOn: Binding($showRemainingDays))
                Toggle("Show next review time", isOn: Binding($showNextReviewTime))
                Toggle("Spread answer buttons", isOn: Binding($disperseAnswerButtons))
            }

            Section("Audio") {
                Toggle("Play audio in silent mode", isOn: Binding($playAudioInSilentMode))
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ReviewSettingsView()
    }
}
