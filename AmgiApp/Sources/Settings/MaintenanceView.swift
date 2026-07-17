import SwiftUI
import AmgiTheme

struct MaintenanceView: View {
    @State private var model = MaintenanceModel()
    @State private var showResetConfirm = false

    @Environment(\.palette) private var palette

    var body: some View {
        Form {
            Section {
                Button("Check Database") { model.checkDatabase() }
            } footer: {
                Text("Verifies the integrity of your local Anki collection.")
            }

            Section {
                Button("Reset Everything", role: .destructive) {
                    showResetConfirm = true
                }
            } footer: {
                Text("Deletes the local collection and credentials. You will need to sync or re-import after.")
            }

            if !model.statusMessage.isEmpty {
                Section("Status") {
                    Text(model.statusMessage)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Reset Everything?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { model.resetEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the local collection database, media, and stored credentials. The action cannot be undone.")
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        MaintenanceView()
    }
}
#endif
