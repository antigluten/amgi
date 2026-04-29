import SwiftUI
import AmgiTheme

struct StatsChartTooltip: View {
    let title: String
    let lines: [String]

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: AmgiSpacing.xxs) {
            Text(title)
                .amgiFont(.captionBold)
                .foregroundStyle(palette.textPrimary)

            ForEach(lines, id: \.self) { line in
                Text(line)
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(.horizontal, AmgiSpacing.sm)
        .padding(.vertical, AmgiSpacing.xs)
        .background(palette.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.border.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

func statsBarRangeLabel(start: Int, bucketSize: Int) -> String {
    if bucketSize <= 1 {
        return "\(start)"
    }

    let end = start + bucketSize - 1
    return "\(start) to \(end)"
}
