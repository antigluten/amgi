//
//  MediumWidgetView.swift
//  WidgetFeature
//
//  Created by Vladimir Gusev on 07.04.2026.
//

import Foundation
import SwiftUI
import WidgetKit
import Theme
import AppCore

struct MediumWidgetView: View {
    @Environment(\.palette) private var palette
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: AmgiSpacing.lg) {
            // Left: streak + hero + deck name
            VStack(alignment: .leading, spacing: 0) {
                StreakLabel(days: snapshot.streak)

                Spacer()

                DueHero(totalDue: snapshot.totalDue)

                Spacer()

                Text(snapshot.deckName)
                    .amgiFont(.micro)
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxHeight: .infinity)

            Rectangle()
                .fill(palette.separator)
                .frame(width: 1)

            // Right: category breakdown + done today
            VStack(alignment: .leading, spacing: AmgiSpacing.sm) {
                CountLegendRow(color: palette.cardStateNew, label: "New", count: snapshot.newCount)
                CountLegendRow(color: palette.cardStateLearning, label: "Learn", count: snapshot.learnCount)
                CountLegendRow(color: palette.cardStateReview, label: "Review", count: snapshot.reviewCount)

                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 1)

                HStack {
                    Text("Done today")
                        .amgiFont(.micro)
                        .foregroundStyle(palette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(snapshot.reviewedToday)")
                        .amgiFont(.micro, .monospacedDigits)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .frame(minWidth: 108)
        }
        .padding(AmgiSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "amgi://review?deckId=\(snapshot.deckId)"))
    }
}

#if DEBUG

// See the note on SmallWidgetView's preview for why this uses a hand-set frame
// instead of any WidgetKit preview API.
#Preview {
    WidgetPreviewFrame(width: 364, height: 170) {
        MediumWidgetView(snapshot: .placeholder)
    }
}
#endif
