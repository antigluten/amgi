//
//  ReviewSettingsView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 02.05.2026.
//

import SwiftUI
import AppCore
import Theme
import Sharing
import ReviewCore
import ReviewFeature

struct ReviewSettingsView: View {
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

    @Shared(.appStorage(ReviewPreferences.Keys.playAudioInSilentMode))
    private var playAudioInSilentMode: Bool = false

    var body: some View {
        SettingsPage {
            cardDisplaySection
            answerButtonsSection
            audioSection
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cardDisplaySection: some View {
        Group {
            SettingsSectionHeader(title: "Card Display")
            SettingsGroup {
                SettingsToggleRow(
                    title: "Match toolbar to card background",
                    systemImage: "paintbrush",
                    tone: .mature,
                    isOn: Binding($autoMatchCardBackground)
                )
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Open links externally",
                    systemImage: "arrow.up.right.square",
                    tone: .accent,
                    isOn: Binding($openLinksExternally)
                )
                SettingsSeparator()
                SettingsPickerRow(
                    title: "Content alignment",
                    systemImage: "arrow.up.and.down.text.horizontal",
                    tone: .link,
                    selection: Binding($cardContentAlignment)
                ) {
                    Text("Center").tag(CardWebViewContentAlignment.center.rawValue)
                    Text("Top").tag(CardWebViewContentAlignment.top.rawValue)
                }
            }
        }
    }

    private var answerButtonsSection: some View {
        Group {
            SettingsSectionHeader(title: "Answer Buttons")
            SettingsGroup {
                SettingsToggleRow(
                    title: "Show remaining counts",
                    systemImage: "number",
                    tone: .review,
                    isOn: Binding($showRemainingDays)
                )
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Show next review time",
                    systemImage: "clock",
                    tone: .info,
                    isOn: Binding($showNextReviewTime)
                )
            }
        }
    }

    private var audioSection: some View {
        Group {
            SettingsSectionHeader(title: "Audio")
            SettingsGroup {
                SettingsToggleRow(
                    title: "Play audio in silent mode",
                    systemImage: "speaker.wave.2",
                    tone: .learning,
                    isOn: Binding($playAudioInSilentMode)
                )
            }
        }
    }
}

#if DEBUG

#Preview {
    NavigationStack {
        ReviewSettingsView()
    }
}
#endif
