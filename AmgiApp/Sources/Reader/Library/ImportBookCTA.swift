import AmgiTheme
import SwiftUI

struct ImportBookCTA: View {
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Label("Import EPUB", systemImage: "plus")
                .amgiFont(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .background(palette.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: AmgiRadius.hero))
        .foregroundStyle(.tint)
        .padding(.horizontal, 16)
    }
}

#Preview {
    ImportBookCTA(action: {})
        .padding(.vertical)
}
