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
                SettingsSeparator()
                Link(destination: URL(string: "https://github.com/antigluten/amgi")!) {
                    SettingsValueRow(
                        title: "Source code",
                        value: "antigluten/amgi",
                        systemImage: "chevron.left.forwardslash.chevron.right",
                        tone: .info
                    )
                }
                .buttonStyle(.plain)
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
                Link(destination: URL(string: "https://github.com/antigluten/amgi/blob/main/CONTRIBUTORS.md")!) {
                    SettingsValueRow(
                        title: "Community",
                        value: "Contributors",
                        systemImage: "person.2",
                        tone: .learning
                    )
                }
                .buttonStyle(.plain)
            }
            SettingsFootnote("Amgi is free software under AGPL-3.0; the full source of every release is at github.com/antigluten/amgi. It uses the official Anki Rust backend, which remains the work of its authors.")
            SettingsFootnote("Anki is a registered trademark of Ankitects Pty Ltd. Amgi is not affiliated with or endorsed by Ankitects.")
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
