//
//  DeckDetailBanners.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 16.05.2026.
//

import SwiftUI
import Theme

struct FeedbackToast: View {
    let feedback: String?
    let onDismiss: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        if let feedback {
            Button(action: onDismiss) {
                Text(feedback)
                    .amgiFont(.bodyEmphasis)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(palette.accent, in: Capsule())
            }
            .buttonStyle(.pressScale)
            .accessibilityHint("Dismisses this message")
            .padding(.bottom, 24)
            .transition(AmgiMotion.slide(from: .bottom))
        }
    }
}
