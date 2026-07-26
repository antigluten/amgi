import SwiftUI
import SwiftNavigation
import SwiftUINavigation

/// Drives every modal axis (alert + sheet) from `destination`. Sub-views own
/// the alert title/actions/message rendering so this modifier stays a flat
/// composition.
struct DeckConfigPresentations: ViewModifier {
    @Binding var destination: DeckConfigDestination?
    let currentAlert: DeckConfigAlert?
    let alertTitle: String
    @Binding var newPresetName: String
    @Binding var renamePresetDraft: String
    let deletingPresetName: String?
    let fallbackPresetName: String?
    let onCreate: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onDismissSheet: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                alertTitle,
                isPresented: Binding($destination.alert),
                presenting: currentAlert
            ) { alert in
                DeckConfigAlertActions(
                    alert: alert,
                    newPresetName: $newPresetName,
                    renamePresetDraft: $renamePresetDraft,
                    onCreate: onCreate,
                    onRename: onRename,
                    onDelete: onDelete
                )
            } message: { alert in
                DeckConfigAlertMessage(
                    alert: alert,
                    deletingPresetName: deletingPresetName,
                    fallbackPresetName: fallbackPresetName
                )
            }
            .sheet(item: $destination.sheet) { sheet in
                DeckConfigSheetContent(sheet: sheet, onDismiss: onDismissSheet)
            }
    }
}

struct DeckConfigAlertActions: View {
    let alert: DeckConfigAlert
    @Binding var newPresetName: String
    @Binding var renamePresetDraft: String
    let onCreate: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        switch alert {
        case .saveFailed, .fsrsError, .presetError:
            Button("OK", role: .cancel) {}
        case .createPreset:
            TextField("Preset name", text: $newPresetName)
                .autocorrectionDisabled()
            Button("Create") { onCreate() }
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {}
        case .renamePreset:
            TextField("Preset name", text: $renamePresetDraft)
                .autocorrectionDisabled()
            Button("Save") { onRename() }
                .disabled(renamePresetDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {}
        case .deletePresetConfirm:
            Button("Delete", role: .destructive) { onDelete() }
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
        case .saveFailed(let msg), .fsrsError(let msg), .presetError(let msg):
            Text(msg)
        case .createPreset:
            Text("New preset will be cloned from the current one and selected for this deck.")
        case .renamePreset:
            EmptyView()
        case .deletePresetConfirm:
            if let name = deletingPresetName, let fallback = fallbackPresetName {
                Text("\"\(name)\" will be removed and decks using it will switch to \"\(fallback)\".")
            } else {
                Text("This preset will be removed.")
            }
        }
    }
}

struct DeckConfigSheetContent: View {
    let sheet: DeckConfigSheet
    let onDismiss: () -> Void

    var body: some View {
        switch sheet {
        case .simulator(let context):
            FsrsSimulatorView(context: context, onDismiss: onDismiss)
        }
    }
}
