import SwiftUI
import AmgiTheme

struct AnkiMobileAttributionView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sync provided by AnkiWeb", systemImage: "icloud.and.arrow.up.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
            Text("AnkiWeb is supported by sales of AnkiMobile. Please consider purchasing a copy to support the sync servers.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
            Button {
                openAnkiMobile()
            } label: {
                Label("View AnkiMobile in App Store", systemImage: "apps.iphone")
            }
            .font(.footnote.weight(.medium))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func openAnkiMobile() {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/id373493387") else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    AnkiMobileAttributionView()
        .padding()
}
