//
//  SyncSettingsView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 28.04.2026.
//

import SwiftUI
import Theme
import SyncFeature
import AppCore
import AnkiSync
import Sharing

struct SyncSettingsView: View {
    @Shared(.syncMode) private var syncMode
    @State private var endpoint: String? = KeychainHelper.loadEndpoint()
    @State private var username: String? = KeychainHelper.loadUsername()
    @State private var isLoggedIn: Bool = KeychainHelper.loadHostKey() != nil
    @State private var showServerSetup = false
    @State private var showDisableConfirm = false
    @State private var showLogoutConfirm = false

    @Environment(\.palette) private var palette

    var body: some View {
        SettingsPage {
            if let endpoint {
                configuredSections(endpoint: endpoint)
            } else {
                disabledSection
            }
        }
        .navigationTitle("Sync Server")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showServerSetup) {
            ServerSetupView {
                endpoint = KeychainHelper.loadEndpoint()
                username = KeychainHelper.loadUsername()
                isLoggedIn = KeychainHelper.loadHostKey() != nil
            }
        }
        .confirmationDialog(
            "Disable Sync?",
            isPresented: $showDisableConfirm,
            titleVisibility: .visible
        ) {
            Button("Disable", role: .destructive) { disableSync() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes the server, credentials, and switches the app to local-only mode.")
        }
        .confirmationDialog(
            "Log out?",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) { logout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes the stored credentials for this server. Your local collection is unaffected; you can sign in again at any time.")
        }
    }

    // MARK: - Configured

    @ViewBuilder
    private func configuredSections(endpoint: String) -> some View {
        SettingsGroup {
            AnkiMobileAttributionView()
                .padding(.horizontal, AmgiSpacing.lg)
                .padding(.vertical, AmgiSpacing.md)
        }
        .padding(.top, AmgiSpacing.lg)

        SettingsSectionHeader(title: "Server")
        SettingsGroup {
            SettingsValueRow(
                title: "URL",
                value: endpoint,
                systemImage: "link",
                tone: .info,
                truncation: .middle
            )
        }

        SettingsSectionHeader(title: "Account")
        SettingsGroup {
            SettingsValueRow(
                title: "Username",
                value: username ?? "Not signed in",
                systemImage: "person.crop.circle",
                tone: .accent,
                isMuted: username == nil
            )
            SettingsSeparator()
            SettingsValueRow(
                title: "Credentials",
                value: isLoggedIn ? "Stored" : "Not signed in",
                systemImage: "key",
                tone: .neutral
            )
        }

        SettingsSectionHeader(title: "Actions")
        SettingsGroup {
            SettingsButtonRow(
                title: "Change Server…",
                systemImage: "arrow.triangle.2.circlepath",
                tone: .info
            ) {
                showServerSetup = true
            }
            SettingsSeparator()
            SettingsButtonRow(
                title: "Log Out…",
                systemImage: "rectangle.portrait.and.arrow.right",
                tone: .danger,
                isDestructive: true
            ) {
                showLogoutConfirm = true
            }
            .disabled(!isLoggedIn)
        }

        SettingsGroup {
            SettingsButtonRow(
                title: "Disable Sync (Local Only)…",
                systemImage: "iphone.slash",
                tone: .danger,
                isDestructive: true
            ) {
                showDisableConfirm = true
            }
        }
        .padding(.top, AmgiSpacing.lg)
        SettingsFootnote("Stops syncing. Your local collection is unaffected.")
    }

    // MARK: - Not configured

    @ViewBuilder
    private var disabledSection: some View {
        SettingsGroup {
            SettingsValueRow(
                title: "Sync",
                value: "Disabled",
                systemImage: "iphone",
                tone: .neutral
            )
            SettingsSeparator()
            SettingsButtonRow(
                title: "Set Up Server…",
                systemImage: "arrow.triangle.2.circlepath",
                tone: .accent
            ) {
                showServerSetup = true
            }
        }
        .padding(.top, AmgiSpacing.lg)
        SettingsFootnote("Amgi works fully offline. Add a server only if you want to sync with AnkiWeb or a self-hosted instance.")
    }
}

private extension SyncSettingsView {
    func logout() {
        KeychainHelper.deleteHostKey()
        KeychainHelper.deleteUsername()
        username = nil
        isLoggedIn = false
    }

    func disableSync() {
        KeychainHelper.deleteHostKey()
        KeychainHelper.deleteUsername()
        KeychainHelper.deleteEndpoint()
        $syncMode.withLock { $0 = .local }
        endpoint = nil
        username = nil
        isLoggedIn = false
    }
}

private struct ServerSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Shared(.syncMode) private var syncMode
    @State private var url: String = KeychainHelper.loadEndpoint() ?? ""
    @State private var endpointError: String?
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            SettingsPage {
                SettingsSectionHeader(title: "Sync Server URL")
                SettingsGroup {
                    TextField(
                        "Sync server URL",
                        text: $url,
                        // Explicit prompt: the default placeholder picks up
                        // the tint and renders accent-blue inside the group.
                        prompt: Text("https://sync.example.com")
                            .foregroundStyle(palette.textTertiary)
                    )
                        .amgiFont(.body)
                        .foregroundStyle(palette.textPrimary)
                        .labelsHidden()
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .padding(.horizontal, AmgiSpacing.lg)
                        .padding(.vertical, AmgiSpacing.md)
                        .frame(minHeight: 44)
                }
                SettingsFootnote(endpointError ?? "Enter the URL of your Anki-compatible sync server.")

                SettingsGroup {
                    SettingsButtonRow(
                        title: "Save",
                        systemImage: "checkmark",
                        tone: .accent,
                        action: save
                    )
                    .disabled(trimmed.isEmpty)
                }
                .padding(.top, AmgiSpacing.lg)
            }
            .navigationTitle("Sync Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var trimmed: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension ServerSetupView {
    func save() {
        do {
            let normalized = try SyncEndpoint.normalized(trimmed)
            try KeychainHelper.saveEndpoint(normalized)
            endpointError = nil
            $syncMode.withLock { $0 = .custom }
            KeychainHelper.deleteHostKey()  // force re-auth on next sync
            onSave()
            dismiss()
        } catch {
            endpointError = error.localizedDescription
        }
    }
}

#if DEBUG

// MARK: - Preview

#Preview {
    NavigationStack { SyncSettingsView() }
}
#endif
