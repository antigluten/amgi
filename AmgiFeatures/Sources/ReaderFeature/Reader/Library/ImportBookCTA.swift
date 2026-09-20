//
//  ImportBookCTA.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 17.05.2026.
//

import Theme
import SwiftUI

struct ImportBookCTA: View {
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Label("Import EPUB", systemImage: "square.and.arrow.down")
                .amgiFont(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.pressScale)
        .background(palette.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: AmgiRadius.hero))
        .foregroundStyle(.tint)
        .padding(.horizontal, 16)
    }
}

#if DEBUG

#Preview {
    ImportBookCTA(action: {})
        .padding(.vertical)
}
#endif
