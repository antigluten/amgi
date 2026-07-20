import SwiftUI
import AmgiCardWeb
import AmgiTheme

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
                        .font(.caption.monospaced())
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(palette.textTertiary)
            }
        }
        .buttonStyle(.plain)
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
