//
//  RenderModeChipRow.swift
//  ReviewFeature
//
//  Created by Vladimir Gusev on 20.07.2026.
//

import SwiftUI
import AmgiCardWeb
import Theme

/// R11 chip row between the counts bar and the card: resolved-mode badge
/// (Native green / HTML orange), an "auto" caption when the mode came from
/// auto-detection, and the template name in mono. Tapping opens
/// `RenderModeSheet`.
struct RenderModeChipRow: View {
    let isNative: Bool
    let isAuto: Bool
    let templateName: String?
    let onTap: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                badge
                if isAuto {
                    Text("auto")
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                if let templateName {
                    Text(templateName)
                        .amgiFont(.micro, .monospaced)
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .amgiFont(.micro)
                    .foregroundStyle(palette.textTertiary)
                    .accessibilityHidden(true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressScale)
        .accessibilityLabel("Rendering: \(isNative ? "Native" : "HTML")\(isAuto ? ", automatic" : "")")
    }

    private var badge: some View {
        Text(isNative ? "Native" : "HTML")
            .amgiFont(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(isNative ? palette.positive : palette.warning)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                (isNative ? palette.positive : palette.warning).opacity(0.12),
                in: Capsule()
            )
    }
}

#if DEBUG
#Preview("Native auto") {
    RenderModeChipRow(isNative: true, isAuto: true, templateName: "Card 1", onTap: {})
        .padding()
}

#Preview("HTML forced") {
    RenderModeChipRow(isNative: false, isAuto: false, templateName: "Cloze", onTap: {})
        .padding()
}
#endif
