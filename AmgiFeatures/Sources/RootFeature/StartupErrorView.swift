//
//  StartupErrorView.swift
//  RootFeature
//
//  Created by Vladimir Gusev on 29.08.2026.
//

import AppCore
import Theme
import UI
import AnkiSync
import Foundation
import SwiftUI

/// Shown when the collection could not be opened at launch.
///
/// Exists so a damaged collection is recoverable in-app. Opening used to be
/// a `try!`, which turned a corrupt `collection.anki2` — the state an
/// interrupted full-download or import leaves behind — into a permanent
/// crash loop whose only remedy was delete-and-reinstall, destroying
/// whatever had not been synced.
struct StartupErrorView: View {
    let message: String

    @Environment(\.palette) private var palette
    @State private var showResetConfirm = false
    @State private var didReset = false

    var body: some View {
        VStack(spacing: AmgiSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .amgiFont(.displayHero)
                .foregroundStyle(palette.textSecondary)

            Text("Couldn't open your collection", bundle: .module)
                .amgiFont(.cardTitle)

            Text(message)
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)

            if didReset {
                Text("Collection removed. Quit and reopen Amgi, then sync to restore your cards.", bundle: .module)
                    .amgiStatusText(.info, font: .caption)
                    .multilineTextAlignment(.center)
            } else {
                Text("If you sync, your cards are safe on the server and will come back after a reset.", bundle: .module)
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)

                Button(String(localized: "Reset This Profile's Collection", bundle: .module), role: .destructive) {
                    showResetConfirm = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(AmgiSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedRoot()
        .confirmationDialog(
            String(localized: "Reset this profile's collection?", bundle: .module),
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete Collection", bundle: .module), role: .destructive) { reset() }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        } message: {
            Text("Deletes the local collection and sync credentials for this profile. Other profiles are untouched.", bundle: .module)
        }
    }

    private func reset() {
        let profileID = AccountStore.shared.current.id
        KeychainHelper.deleteAll(forProfile: profileID)
        try? FileManager.default.removeItem(at: AccountStore.profileDirectory(for: profileID))
        didReset = true
    }
}
