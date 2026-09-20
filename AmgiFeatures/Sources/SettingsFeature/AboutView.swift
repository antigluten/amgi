//
//  AboutView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 28.04.2026.
//

import SwiftUI
import Theme

struct AboutView: View {
    private var appVersion: String {
        let bundle = Bundle.main
        let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        SettingsPage {
            SettingsSectionHeader(title: "Amgi")
            SettingsGroup {
                SettingsValueRow(
                    title: "Version",
                    value: appVersion,
                    systemImage: "number",
                    tone: .info
                )
                SettingsSeparator()
                SettingsValueRow(
                    title: "Korean origin",
                    value: "암기 — memorization",
                    systemImage: "character.book.closed",
                    tone: .mature
                )
            }

            SettingsSectionHeader(title: "Acknowledgements")
            SettingsGroup {
                SettingsValueRow(
                    title: "Anki engine",
                    value: "ankitects/anki",
                    systemImage: "shippingbox",
                    tone: .accent
                )
                SettingsSeparator()
                SettingsValueRow(
                    title: "Community",
                    value: "DreamAfar — fork contributor",
                    systemImage: "person.2",
                    tone: .learning
                )
            }
            SettingsFootnote("Amgi uses the official Anki Rust backend. The backend code is licensed under AGPL-3.0 and remains the work of its authors.")
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG

// MARK: - Preview

#Preview {
    NavigationStack { AboutView() }
}
#endif
