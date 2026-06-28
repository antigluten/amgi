import SwiftUI

/// Compact toolbar menu that exposes profile switching from the Decks
/// tab without forcing the user into Settings. Active profile shows a
/// checkmark; tapping any other profile schedules a switch (consumed
/// at next cold start — see `AccountStore`). Pending switch surfaces
/// as an orange `arrow.triangle.2.circlepath` next to the label so
/// the user remembers to relaunch.
///
/// Add/delete still happens in Settings → Account → Profiles; this
/// menu is a fast picker, not a full manager.
struct ProfilePickerMenu: View {
    @State private var store = AccountStore.shared

    var body: some View {
        Menu {
            Section {
                ForEach(store.accounts) { account in
                    Button {
                        if account.id == store.selectedID {
                            store.clearPending()
                        } else {
                            store.scheduleSwitch(to: account)
                        }
                    } label: {
                        HStack {
                            Text(account.displayName)
                            if account.id == store.selectedID {
                                Image(systemName: "checkmark")
                            } else if account.id == store.pendingSwitchID {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                    }
                }
            } header: {
                Text("Switch profile")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.pendingSwitchID == nil
                      ? "person.crop.circle"
                      : "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(store.pendingSwitchID == nil ? Color.accentColor : .orange)
                Text(store.current.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
        }
        .accessibilityLabel("Profile: \(store.current.displayName)")
    }
}
