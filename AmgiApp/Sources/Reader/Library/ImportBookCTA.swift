import SwiftUI

struct ImportBookCTA: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Import EPUB", systemImage: "plus")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.tint)
        .padding(.horizontal, 16)
    }
}

#Preview {
    ImportBookCTA(action: {})
        .padding(.vertical)
}
