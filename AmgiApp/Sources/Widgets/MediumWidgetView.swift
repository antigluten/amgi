// AmgiApp/Sources/Widgets/MediumWidgetView.swift
import SwiftUI
import WidgetKit
import AmgiTheme

struct MediumWidgetView: View {
    @Environment(\.palette) private var palette
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 16) {
            // Left: streak + hero + deck name
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 16))
                    Text("\(snapshot.streak)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(palette.warning)
                    Text("day streak")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(snapshot.totalDue)")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .kerning(-2)
                    Text("cards due")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer()

                Text(snapshot.deckName)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxHeight: .infinity)

            // Divider
            Rectangle()
                .fill(.separator)
                .frame(width: 1)

            // Right: category breakdown + done today
            VStack(alignment: .leading, spacing: 9) {
                countRow(dot: .blue, label: "New", count: snapshot.newCount)
                countRow(dot: .orange, label: "Learn", count: snapshot.learnCount)
                countRow(dot: .green, label: "Review", count: snapshot.reviewCount)

                Rectangle()
                    .fill(.separator)
                    .frame(height: 1)

                HStack {
                    Text("Done today")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)
                    Spacer()
                    Text("\(snapshot.reviewedToday)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .frame(minWidth: 108)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "amgi://review?deckId=\(snapshot.deckId)"))
    }

    private func countRow(dot: Color, label: String, count: Int) -> some View {
        HStack {
            Circle()
                .fill(dot)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
        }
    }
}

#Preview(as: .systemMedium) {
    AmgiWidget()
} timeline: {
    WidgetEntry(date: Date(), snapshot: .placeholder)
}
