//
//  ProfilePickerMenu.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 05.05.2026.
//

import SwiftUI
import Theme
import AppCore

struct ProfilePickerMenu: View {
    let onSwitch: (AmgiAccount) async -> Void

    @State private var store = AccountStore.shared
    @Environment(\.palette) private var palette

    var body: some View {
        Menu {
            Picker("Switch Profile", selection: selection) {
                ForEach(store.accounts) { account in
                    Text(account.displayName).tag(account.id)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(palette.accent)
                Text(store.current.displayName)
                    .amgiFont(.bodyEmphasis)
                    .lineLimit(1)
            }
        }
        .accessibilityLabel("Profile: \(store.current.displayName)")
    }

    private var selection: Binding<String> {
        Binding(
            get: { store.selectedID },
            set: { newID in
                guard newID != store.selectedID,
                      let account = store.accounts.first(where: { $0.id == newID })
                else { return }
                Task { await onSwitch(account) }
            }
        )
    }
}
