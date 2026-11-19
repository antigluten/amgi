//
//  MaintenanceView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 28.04.2026.
//

import SwiftUI
import Theme

struct MaintenanceView: View {
    @State private var model = MaintenanceModel()
    @State private var showResetConfirm = false

    @Environment(\.palette) private var palette

    var body: some View {
        SettingsPage {
            SettingsSectionHeader(title: String(localized: "Collection", bundle: .module))
            SettingsGroup {
                SettingsButtonRow(
                    title: String(localized: "Check Database", bundle: .module),
                    systemImage: "stethoscope",
                    tone: .info,
                    isBusy: model.isChecking
                ) {
                    Task { await model.checkDatabase() }
                }
                .disabled(model.isChecking)
            }
            SettingsFootnote(String(localized: "Verifies the integrity of your local Anki collection.", bundle: .module))

            SettingsSectionHeader(title: String(localized: "Danger Zone", bundle: .module))
            SettingsGroup {
                SettingsButtonRow(
                    title: String(localized: "Reset Everything…", bundle: .module),
                    systemImage: "trash",
                    tone: .danger,
                    isDestructive: true
                ) {
                    showResetConfirm = true
                }
            }
            SettingsFootnote(String(localized: "Deletes this profile's collection and credentials. You will need to sync or re-import after.", bundle: .module))

            if !model.statusMessage.isEmpty {
                SettingsSectionHeader(title: String(localized: "Status", bundle: .module))
                SettingsGroup {
                    Text(model.statusMessage)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AmgiSpacing.lg)
                        .padding(.vertical, AmgiSpacing.md)
                }
            }
        }
        .navigationTitle(String(localized: "Maintenance", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            String(localized: "Reset Everything?", bundle: .module),
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Reset", bundle: .module), role: .destructive) { Task { await model.resetEverything() } }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        } message: {
            Text("This deletes the active profile's collection database, media, and stored credentials. Other profiles are unaffected. The action cannot be undone.", bundle: .module)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        MaintenanceView()
    }
}
#endif
