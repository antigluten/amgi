import SwiftUI
import AnkiKit

/// Placeholder view for the notetype field manager.
/// Full implementation (add/remove/reorder fields) is a future port.
struct NotetypeFieldManagerView: View {
    let notetypeId: NotetypeID
    let preferredName: String
    var onSaved: (@Sendable () async -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Field editor coming soon.")
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
        }
        .navigationTitle(preferredName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
