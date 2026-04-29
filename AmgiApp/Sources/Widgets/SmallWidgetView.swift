// AmgiApp/Sources/Widgets/SmallWidgetView.swift
import SwiftUI
import WidgetKit
import AmgiTheme

struct SmallWidgetView: View {
    @Environment(\.palette) private var palette
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Streak row
            HStack(spacing: 4) {
                Text("🔥")
                    .font(.system(size: 17))
                Text("\(snapshot.streak)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.warning)
                Text("day streak")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textTertiary)
            }

            Spacer()

            // Hero due count
            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.totalDue)")
                    .font(.system(size: 54, weight: .bold, design: .default))
                    .foregroundStyle(palette.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .kerning(-2)
                Text("cards due")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()

            // Deck name
            Text(snapshot.deckName)
                .font(.system(size: 11))
                .foregroundStyle(palette.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "amgi://review?deckId=\(snapshot.deckId)"))
    }
}

#Preview(as: .systemSmall) {
    AmgiWidget()
} timeline: {
    WidgetEntry(date: Date(), snapshot: .placeholder)
}
