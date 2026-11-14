//
//  DeckConfigPresentations.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import SwiftUI
import SwiftNavigation
import SwiftUINavigation

struct DeckConfigPresentations: ViewModifier {
    @Binding var destination: DeckConfigDestination?
    let currentAlert: DeckConfigAlert?
    let alertTitle: String
    @Binding var newPresetName: String
    @Binding var renamePresetDraft: String
    let currentPresetName: String?
    let deletingPresetName: String?
    let fallbackPresetName: String?
    let onCreate: () async -> String?
    let onRename: () async -> String?
    let onDelete: () -> Void
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                alertTitle,
                isPresented: Binding($destination.alert),
                presenting: currentAlert
            ) { alert in
                DeckConfigAlertActions(alert: alert, onDelete: onDelete, onDiscard: onDiscard)
            } message: { alert in
                DeckConfigAlertMessage(
                    alert: alert,
                    deletingPresetName: deletingPresetName,
                    fallbackPresetName: fallbackPresetName
                )
            }
            .sheet(item: $destination.prompt) { prompt in
                promptSheet(prompt)
            }
            .navigationDestination(item: $destination.route) { route in
                switch route {
                case .simulator(let context):
                    FsrsSimulatorView(context: context)
                }
            }
    }

    @ViewBuilder
    private func promptSheet(_ prompt: DeckConfigPrompt) -> some View {
        switch prompt {
        case .createPreset:
            TextPromptSheet(
                title: String(localized: "Add Preset", bundle: .module),
                placeholder: String(localized: "Preset name", bundle: .module),
                footer: String(localized: "Cloned from \(currentPresetName.map { "\"\($0)\"" } ?? String(localized: "the current preset", bundle: .module)) and selected for this deck.", bundle: .module),
                confirmLabel: String(localized: "Create", bundle: .module),
                isValid: { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                onConfirm: { _ in await onCreate() },
                text: $newPresetName
            )
        case .renamePreset:
            TextPromptSheet(
                title: String(localized: "Rename Preset", bundle: .module),
                placeholder: String(localized: "Preset name", bundle: .module),
                footer: nil,
                confirmLabel: String(localized: "Save", bundle: .module),
                isValid: { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                onConfirm: { _ in await onRename() },
                text: $renamePresetDraft
            )
        }
    }
}

struct DeckConfigAlertActions: View {
    let alert: DeckConfigAlert
    let onDelete: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        switch alert {
        case .saveFailed, .fsrsError, .presetError:
            Button(String(localized: "OK", bundle: .module), role: .cancel) {}
        case .deletePresetConfirm:
            Button(String(localized: "Delete", bundle: .module), role: .destructive) { onDelete() }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        case .discardChanges:
            Button(String(localized: "Discard", bundle: .module), role: .destructive) { onDiscard() }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        }
    }
}

struct DeckConfigAlertMessage: View {
    let alert: DeckConfigAlert
    let deletingPresetName: String?
    let fallbackPresetName: String?

    var body: some View {
        switch alert {
        case .saveFailed(let msg), .presetError(let msg), .fsrsError(_, let msg):
            Text(msg)
        case .deletePresetConfirm:
            if let name = deletingPresetName, let fallback = fallbackPresetName {
                Text("\"\(name)\" will be removed and decks using it will switch to \"\(fallback)\".", bundle: .module)
            } else {
                Text("This preset will be removed.", bundle: .module)
            }
        case .discardChanges:
            Text("You have unsaved changes to this deck's options. Discard them?", bundle: .module)
        }
    }
}
