//
//  WidgetComponents.swift
//  WidgetFeature
//
//  Created by Vladimir Gusev on 06.09.2026.
//

import SwiftUI
import Theme

struct StreakLabel: View {
    @Environment(\.palette) private var palette
    let days: Int

    var body: some View {
        if days > 0 {
            HStack(spacing: AmgiSpacing.xs) {
                Image(systemName: "flame.fill")
                    .amgiFont(size: 12, weight: .bold, relativeTo: .footnote)
                    .accessibilityHidden(true)
                Text("\(days) day streak")
                    .amgiFont(.captionBold, .monospacedDigits)
            }
            .foregroundStyle(palette.warning)
            .lineLimit(1)
            .accessibilityElement(children: .combine)
        }
    }
}

struct DueHero: View {
    @Environment(\.palette) private var palette
    let totalDue: Int
    var axis: Axis = .vertical

    var body: some View {
        let layout = axis == .vertical
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AmgiSpacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: AmgiSpacing.sm))

        layout {
            Text("\(totalDue)")
                .amgiFont(size: 52, weight: .semibold, tracking: -1.2, relativeTo: .largeTitle)
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("cards due")
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct CountLegendRow: View {
    @Environment(\.palette) private var palette
    let color: Color
    let label: String
    let count: Int

    var body: some View {
        HStack(spacing: AmgiSpacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(count)")
                .amgiFont(.captionBold, .monospacedDigits)
                .foregroundStyle(palette.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
struct WidgetPreviewFrame<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        let palette = ThemeRegistry.shared.palette(id: .minimal, scheme: colorScheme)
        content()
            .frame(width: width, height: height)
            .background(
                palette.surface,
                in: .rect(cornerRadius: AmgiRadius.card, style: .continuous)
            )
            .padding(AmgiSpacing.xl)
            .background(palette.background)
            .environment(\.palette, palette)
    }
}
#endif
