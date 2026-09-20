//
//  AnkiMobileAttributionView.swift
//  SyncFeature
//
//  Created by Vladimir Gusev on 02.05.2026.
//

package import SwiftUI
import Theme

package struct AnkiMobileAttributionView: View {
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL

    package init() {}

    package var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sync provided by AnkiWeb", systemImage: "icloud.and.arrow.up.fill")
                .amgiFont(.bodyEmphasis)
                .foregroundStyle(palette.textPrimary)
            Text("AnkiWeb is supported by sales of AnkiMobile. Please consider purchasing a copy to support the sync servers.")
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
            Button {
                openAnkiMobile()
            } label: {
                Label("View AnkiMobile in App Store", systemImage: "apps.iphone")
            }
            .amgiFont(.captionBold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AmgiRadius.inset))
    }
}

private extension AnkiMobileAttributionView {
    func openAnkiMobile() {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/id373493387") else { return }
        openURL(url)
    }
}

#if DEBUG

#Preview {
    AnkiMobileAttributionView()
        .padding()
}
#endif
