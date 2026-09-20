//
//  StatsChartTooltip.swift
//  StatsCharts
//
//  Created by Vladimir Gusev on 28.04.2026.
//

import SwiftUI
import Theme
import UI

struct StatsChartTooltip: View {
    let title: String
    let lines: [String]

    public init(title: String, lines: [String]) {
        self.title = title
        self.lines = lines
    }

    @Environment(\.palette) private var palette

    public var body: some View {
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
        .overlay {
            if palette.elevation != .ring {
                RoundedRectangle(cornerRadius: AmgiRadius.inset)
                    .stroke(palette.border.opacity(0.3), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AmgiRadius.inset))
        .amgiChromeShadow(RoundedRectangle(cornerRadius: AmgiRadius.inset), radius: 12, y: 6, opacity: 0.12)
    }
}

func statsBarRangeLabel(start: Int, bucketSize: Int) -> String {
    if bucketSize <= 1 {
        return "\(start)"
    }

    let end = start + bucketSize - 1
    return "\(start) to \(end)"
}
