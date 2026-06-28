import SwiftUI

/// Profile picker / manager. Each row is one `AmgiAccount`; the active
/// row shows a checkmark, others can be tapped to schedule a switch on
/// next cold start. Add via `+`, swipe to delete (with optional
/// "delete files" prompt).
struct AccountsSettingsView: View {
    @State private var store = AccountStore.shared
    @State private var showAddSheet = false
    @State private var newName = ""
    @State private var addError: String?
    @State private var pendingDelete: AmgiAccount?
    @State private var deleteError: String?

    var body: some View {
        Form {
            pendingBanner
            profilesSection
            addSection
        }
        .navigationTitle("Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            addProfileSheet
        }
        .alert(
            "Delete \(pendingDelete?.displayName ?? "")?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { account in
            Button("Delete profile only", role: .destructive) {
                attemptDelete(account, deleteFiles: false)
            }
            Button("Delete profile and files", role: .destructive) {
                attemptDelete(account, deleteFiles: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Files include the Anki collection, media, and per-profile sync state. Deleting only the profile leaves the files on disk; you can re-add the profile to recover.")
        }
        .alert(
            "Couldn't delete profile",
            isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    @ViewBuilder
    private var pendingBanner: some View {
        if let pending = store.pendingSwitchID,
           let target = store.accounts.first(where: { $0.id == pending }),
           target.id != store.selectedID {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Restart to switch to \(target.displayName)", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.orange)
                    Text("Force-quit and relaunch the app to apply.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Cancel switch") { store.clearPending() }
                        .font(.caption)
                }
            }
        }
    }

    private var profilesSection: some View {
        Section("Profiles") {
            ForEach(store.accounts) { account in
                profileRow(account)
            }
        }
    }

    @ViewBuilder
    private func profileRow(_ account: AmgiAccount) -> some View {
        Button {
            if account.id == store.selectedID {
                store.clearPending()
            } else {
                store.scheduleSwitch(to: account)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName).foregroundStyle(.primary)
                    Text("Created \(account.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if account.id == store.selectedID {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                } else if account.id == store.pendingSwitchID {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.orange)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingDelete = account
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(account.id == store.selectedID || store.accounts.count <= 1)
        }
    }

    private var addSection: some View {
        Section {
            Button {
                newName = ""
                addError = nil
                showAddSheet = true
            } label: {
                Label("New profile", systemImage: "plus")
            }
        } footer: {
            Text("Each profile keeps its own collection, sync login, and review history. Switching takes effect after a relaunch.")
        }
    }

    private var addProfileSheet: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Korean", text: $newName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                if let addError {
                    Text(addError).foregroundStyle(.red).font(.caption)
                }
            }
            .navigationTitle("New profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { attemptAdd() }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func attemptAdd() {
        do {
            _ = try store.add(displayName: newName)
            showAddSheet = false
        } catch {
            addError = error.localizedDescription
        }
    }

    private func attemptDelete(_ account: AmgiAccount, deleteFiles: Bool) {
        do {
            try store.remove(account, deleteFiles: deleteFiles)
        } catch {
            deleteError = error.localizedDescription
        }
        pendingDelete = nil
    }
}
