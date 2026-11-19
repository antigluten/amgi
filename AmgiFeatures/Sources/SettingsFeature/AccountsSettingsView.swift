//
//  AccountsSettingsView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 05.05.2026.
//

import SwiftUI
import Theme
import AppCore
import AnkiSync
import CasePaths
import Sharing
import SwiftUINavigation

/// Profile picker / manager. Each row is one `AmgiAccount`; the active
/// row shows a checkmark, tapping any other switches immediately. Add
/// via `+`, swipe to delete (with optional "delete files" prompt).
struct AccountsSettingsView: View {
    /// Composition-root work: closes/reopens the collection, cancels sync and
    /// flips the keychain anchor, so it stays in `AmgiAppApp.swift` and
    /// arrives here through `SettingsView`.
    let onSwitchProfile: (AmgiAccount) async -> Void

    @State private var store = AccountStore.shared
    @State private var destination: Destination?
    @Shared(.appStorage(AppearancePreferences.Keys.showProfileInToolbar))
    private var showProfileInToolbar = true

    /// One axis for the add sheet and both delete alerts. The add sheet's
    /// name field and validation error only exist while it's up, so they
    /// ride along in the case rather than as two more `@State`s that outlive
    /// it — and a delete error can no longer be raised over a live sheet.
    @CasePathable
    enum Destination {
        case add(NewProfile)
        case confirmDelete(AmgiAccount)
        case deleteFailed(String)
    }

    /// In-flight new profile: the name the sheet's text field edits, plus
    /// whatever `AccountStore.add` rejected it with.
    struct NewProfile {
        var name = ""
        var error: String?
    }

    @Environment(\.palette) private var palette

    // Stays a `List` rather than moving to `SettingsPage`: profile rows carry
    // `swipeActions`, which only exist inside a List. The design chrome
    // (palette background, elevated row surfaces, tinted tiles) is applied
    // to the List instead, so it reads like the rest of Settings without
    // losing swipe-to-delete.
    var body: some View {
        List {
            profilesSection
            addSection
            toolbarSection
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .navigationTitle(String(localized: "Profiles", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding($destination.add)) {
            addProfileSheet
        }
        .confirmationDialog(
            String(localized: "Delete \(pendingDelete?.displayName ?? "")?", bundle: .module),
            isPresented: Binding($destination.confirmDelete),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { account in
            Button(String(localized: "Delete profile only", bundle: .module), role: .destructive) {
                attemptDelete(account, deleteFiles: false)
            }
            Button(String(localized: "Delete profile and files", bundle: .module), role: .destructive) {
                attemptDelete(account, deleteFiles: true)
            }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        } message: { _ in
            Text("Files include the Anki collection, media, and per-profile sync state. Deleting only the profile leaves the files on disk; you can re-add the profile to recover.", bundle: .module)
        }
        .alert(
            String(localized: "Couldn't delete profile", bundle: .module),
            isPresented: Binding($destination.deleteFailed)
        ) {
            Button(String(localized: "OK", bundle: .module), role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var pendingDelete: AmgiAccount? {
        if case .confirmDelete(let account) = destination { return account }
        return nil
    }

    private var deleteError: String? {
        if case .deleteFailed(let message) = destination { return message }
        return nil
    }

    private var pendingAdd: NewProfile? {
        if case .add(let draft) = destination { return draft }
        return nil
    }

    private var addError: String? { pendingAdd?.error }

    /// The add sheet's text field edits the draft in place inside
    /// `destination`, so there's no second copy of the name to keep in sync.
    private var newName: Binding<String> {
        Binding(
            get: { pendingAdd?.name ?? "" },
            set: { newValue in
                guard var draft = pendingAdd else { return }
                draft.name = newValue
                destination = .add(draft)
            }
        )
    }

    private var toolbarSection: some View {
        Section {
            Toggle(String(localized: "Show in Library toolbar", bundle: .module), isOn: Binding($showProfileInToolbar))
                .listRowBackground(palette.surfaceElevated)
        } footer: {
            Text("The profile switcher is hidden automatically while you have only one profile. Profiles are always available here.", bundle: .module)
        }
    }

    private var profilesSection: some View {
        Section {
            ForEach(store.accounts) { account in
                profileRow(account)
                    .listRowBackground(palette.surfaceElevated)
            }
        } header: {
            SettingsListHeader(String(localized: "Profiles", bundle: .module))
        }
    }

    private var addSection: some View {
        Section {
            Button {
                destination = .add(NewProfile())
            } label: {
                HStack(spacing: AmgiSpacing.md) {
                    SettingsIconTile(systemImage: "plus", tone: .accent)
                    Text("New profile", bundle: .module)
                        .amgiFont(.body)
                        .foregroundStyle(palette.textPrimary)
                }
            }
            .listRowBackground(palette.surfaceElevated)
        } footer: {
            Text("Each profile keeps its own collection, sync login, and review history. Switching applies immediately.", bundle: .module)
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var addProfileSheet: some View {
        NavigationStack {
            SettingsPage {
                SettingsSectionHeader(title: String(localized: "Name", bundle: .module))
                SettingsGroup {
                    TextField(
                        String(localized: "Profile name", bundle: .module),
                        text: newName,
                        prompt: Text("e.g. Korean", bundle: .module).foregroundStyle(palette.textTertiary)
                    )
                        .amgiFont(.body)
                        .foregroundStyle(palette.textPrimary)
                        .labelsHidden()
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(.horizontal, AmgiSpacing.lg)
                        .padding(.vertical, AmgiSpacing.md)
                        .frame(minHeight: 44)
                }
                if let addError {
                    SettingsFootnote(addError)
                        .foregroundStyle(palette.danger)
                }
            }
            .navigationTitle(String(localized: "New profile", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", bundle: .module)) { destination = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Add", bundle: .module)) { attemptAdd() }
                        .disabled(newName.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

}

private extension AccountsSettingsView {
    @ViewBuilder
    func profileRow(_ account: AmgiAccount) -> some View {
        Button {
            guard account.id != store.selectedID else { return }
            Task { await onSwitchProfile(account) }
        } label: {
            HStack(spacing: AmgiSpacing.md) {
                ProfileMonogram(name: account.displayName)
                VStack(alignment: .leading, spacing: AmgiSpacing.xxs) {
                    Text(account.displayName)
                        .amgiFont(.body)
                        .foregroundStyle(palette.textPrimary)
                    Text("Created \(account.createdAt.formatted(date: .abbreviated, time: .omitted))", bundle: .module)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer(minLength: AmgiSpacing.sm)
                if account.id == store.selectedID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                destination = .confirmDelete(account)
            } label: {
                Label(String(localized: "Delete", bundle: .module), systemImage: "trash")
            }
            .disabled(account.id == store.selectedID || store.accounts.count <= 1)
        }
    }

    func attemptAdd() {
        guard var draft = pendingAdd else { return }
        do {
            _ = try store.add(displayName: draft.name)
            destination = nil
        } catch {
            draft.error = error.localizedDescription
            destination = .add(draft)
        }
    }

    func attemptDelete(_ account: AmgiAccount, deleteFiles: Bool) {
        do {
            try store.remove(account, deleteFiles: deleteFiles)
            // Credentials are keyed by profile slug, and the slug is derived
            // from the display name — so recreating a profile with the same
            // name would otherwise silently re-adopt the deleted account's
            // AnkiWeb login. Remove them with the profile.
            KeychainHelper.deleteAll(forProfile: account.id)
            destination = nil
        } catch {
            destination = .deleteFailed(error.localizedDescription)
        }
    }
}

// MARK: - Monogram

/// The design's gradient profile avatar, at row scale. Uses the same
/// accent→link ramp as the mock's `linear-gradient(135deg,#0a84ff,#5e5ce6)`,
/// resolved from the palette so it follows the active theme.
private struct ProfileMonogram: View {
    @Environment(\.palette) private var palette

    let name: String

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    var body: some View {
        Text(initial)
            .amgiFont(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                LinearGradient(
                    colors: [palette.accent, palette.link],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
    }
}

#if DEBUG

// MARK: - Preview

#Preview {
    NavigationStack { AccountsSettingsView(onSwitchProfile: { _ in }) }
}
#endif
