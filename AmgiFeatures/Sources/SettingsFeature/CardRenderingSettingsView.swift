//
//  CardRenderingSettingsView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 20.07.2026.
//

import SwiftUI
import AmgiCardWeb
import Theme
import AppCore
import Sharing
import ReviewCore
// MemberImportVisibility: CardRenderEngine is ReviewCore's, but its
// `displayName`/`summary` display helpers are ReviewFeature extensions.
import ReviewFeature

/// R11 "Card Rendering" settings: global engine picker plus a link to the
/// per-template overrides list. Lives under the Review section until the
/// R24 Settings restructure re-homes it.
struct CardRenderingSettingsView: View {
    @Shared(.appStorage(ReviewPreferences.Keys.cardRenderEngine))
    private var engineRaw: String = CardRenderEngine.auto.rawValue

    @Shared(.appStorage(ReviewPreferences.Keys.templateRenderOverrides))
    private var overridesRaw: String = "{}"

    var body: some View {
        SettingsPage {
            // Headerless, like the mock's first group — a "Engine" header
            // above a row also called Engine just says it twice.
            SettingsGroup {
                SettingsPickerRow(
                    title: "Engine",
                    systemImage: "cpu",
                    tone: .accent,
                    selection: engineBinding
                ) {
                    ForEach(CardRenderEngine.allCases, id: \.self) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
            }
            .padding(.top, AmgiSpacing.lg)
            SettingsFootnote(selectedEngine.summary)

            SettingsSectionHeader(title: "Overrides")
            SettingsGroup {
                SettingsRowLink(
                    title: "Per-template overrides",
                    systemImage: "arrow.turn.down.right",
                    tone: .neutral,
                    detail: "\(overrideCount) set"
                ) {
                    TemplateOverridesView()
                }
            }
            SettingsFootnote("Overrides pick an engine for every card of one template and beat the global choice. Stored on this device only.")
        }
        .navigationTitle("Card Rendering")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedEngine: CardRenderEngine {
        CardRenderEngine(rawValue: engineRaw) ?? .auto
    }

    private var overrideCount: Int {
        TemplateRenderOverrides.entries(in: overridesRaw).count
    }

    private var engineBinding: Binding<CardRenderEngine> {
        Binding(
            get: { selectedEngine },
            set: { newValue in $engineRaw.withLock { $0 = newValue.rawValue } }
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CardRenderingSettingsView()
    }
}
#endif
