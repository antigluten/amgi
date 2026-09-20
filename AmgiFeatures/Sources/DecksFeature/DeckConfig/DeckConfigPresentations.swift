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
                title: "Add Preset",
                placeholder: "Preset name",
                footer: "Cloned from \(currentPresetName.map { "\"\($0)\"" } ?? "the current preset") and selected for this deck.",
                confirmLabel: "Create",
                isValid: { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                onConfirm: { _ in await onCreate() },
                text: $newPresetName
            )
        case .renamePreset:
            TextPromptSheet(
                title: "Rename Preset",
                placeholder: "Preset name",
                footer: nil,
                confirmLabel: "Save",
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
            Button("OK", role: .cancel) {}
        case .deletePresetConfirm:
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        case .discardChanges:
            Button("Discard", role: .destructive) { onDiscard() }
            Button("Cancel", role: .cancel) {}
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
                Text("\"\(name)\" will be removed and decks using it will switch to \"\(fallback)\".")
            } else {
                Text("This preset will be removed.")
            }
        case .discardChanges:
            Text("You have unsaved changes to this deck's options. Discard them?")
        }
    }
}
