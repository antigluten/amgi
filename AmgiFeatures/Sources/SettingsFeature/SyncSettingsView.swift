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
        .navigationTitle(String(localized: "Sync Server", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showServerSetup) {
            ServerSetupView {
                endpoint = KeychainHelper.loadEndpoint()
                username = KeychainHelper.loadUsername()
                isLoggedIn = KeychainHelper.loadHostKey() != nil
            }
        }
        .confirmationDialog(
            String(localized: "Disable Sync?", bundle: .module),
            isPresented: $showDisableConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Disable", bundle: .module), role: .destructive) { disableSync() }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        } message: {
            Text("Removes the server, credentials, and switches the app to local-only mode.", bundle: .module)
        }
        .confirmationDialog(
            String(localized: "Log out?", bundle: .module),
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Log Out", bundle: .module), role: .destructive) { logout() }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        } message: {
            Text("Removes the stored credentials for this server. Your local collection is unaffected; you can sign in again at any time.", bundle: .module)
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

        SettingsSectionHeader(title: String(localized: "Server", bundle: .module))
        SettingsGroup {
            SettingsValueRow(
                title: "URL",
                value: endpoint,
                systemImage: "link",
                tone: .info,
                truncation: .middle
            )
        }

        SettingsSectionHeader(title: String(localized: "Account", bundle: .module))
        SettingsGroup {
            SettingsValueRow(
                title: String(localized: "Username", bundle: .module),
                value: username ?? String(localized: "Not signed in", bundle: .module),
                systemImage: "person.crop.circle",
                tone: .accent,
                isMuted: username == nil
            )
            SettingsSeparator()
            SettingsValueRow(
                title: String(localized: "Credentials", bundle: .module),
                value: isLoggedIn ? String(localized: "Stored", bundle: .module) : String(localized: "Not signed in", bundle: .module),
                systemImage: "key",
                tone: .neutral
            )
        }

        SettingsSectionHeader(title: String(localized: "Actions", bundle: .module))
        SettingsGroup {
            SettingsButtonRow(
                title: String(localized: "Change Server…", bundle: .module),
                systemImage: "arrow.triangle.2.circlepath",
                tone: .info
            ) {
                showServerSetup = true
            }
            SettingsSeparator()
            SettingsButtonRow(
                title: String(localized: "Log Out…", bundle: .module),
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
                title: String(localized: "Disable Sync (Local Only)…", bundle: .module),
                systemImage: "iphone.slash",
                tone: .danger,
                isDestructive: true
            ) {
                showDisableConfirm = true
            }
        }
        .padding(.top, AmgiSpacing.lg)
        SettingsFootnote(String(localized: "Stops syncing. Your local collection is unaffected.", bundle: .module))
    }

    // MARK: - Not configured

    @ViewBuilder
    private var disabledSection: some View {
        SettingsGroup {
            SettingsValueRow(
                title: String(localized: "Sync", bundle: .module),
                value: String(localized: "Disabled", bundle: .module),
                systemImage: "iphone",
                tone: .neutral
            )
            SettingsSeparator()
            SettingsButtonRow(
                title: String(localized: "Set Up Server…", bundle: .module),
                systemImage: "arrow.triangle.2.circlepath",
                tone: .accent
            ) {
                showServerSetup = true
            }
        }
        .padding(.top, AmgiSpacing.lg)
        SettingsFootnote(String(localized: "Amgi works fully offline. Add a server only if you want to sync with AnkiWeb or a self-hosted instance.", bundle: .module))
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
                SettingsSectionHeader(title: String(localized: "Sync Server URL", bundle: .module))
                SettingsGroup {
                    TextField(
                        String(localized: "Sync server URL", bundle: .module),
                        text: $url,
                        // Explicit prompt: the default placeholder picks up
                        // the tint and renders accent-blue inside the group.
                        prompt: Text("https://sync.example.com", bundle: .module)
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
                SettingsFootnote(endpointError ?? String(localized: "Enter the URL of your Anki-compatible sync server.", bundle: .module))

                SettingsGroup {
                    SettingsButtonRow(
                        title: String(localized: "Save", bundle: .module),
                        systemImage: "checkmark",
                        tone: .accent,
                        action: save
                    )
                    .disabled(trimmed.isEmpty)
                }
                .padding(.top, AmgiSpacing.lg)
            }
            .navigationTitle(String(localized: "Sync Server", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", bundle: .module)) { dismiss() }
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
