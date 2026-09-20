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
            SettingsSectionHeader(title: "Collection")
            SettingsGroup {
                SettingsButtonRow(
                    title: "Check Database",
                    systemImage: "stethoscope",
                    tone: .info,
                    isBusy: model.isChecking
                ) {
                    Task { await model.checkDatabase() }
                }
                .disabled(model.isChecking)
            }
            SettingsFootnote("Verifies the integrity of your local Anki collection.")

            SettingsSectionHeader(title: "Danger Zone")
            SettingsGroup {
                SettingsButtonRow(
                    title: "Reset Everything…",
                    systemImage: "trash",
                    tone: .danger,
                    isDestructive: true
                ) {
                    showResetConfirm = true
                }
            }
            SettingsFootnote("Deletes this profile's collection and credentials. You will need to sync or re-import after.")

            if !model.statusMessage.isEmpty {
                SettingsSectionHeader(title: "Status")
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
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Reset Everything?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { Task { await model.resetEverything() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the active profile's collection database, media, and stored credentials. Other profiles are unaffected. The action cannot be undone.")
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
