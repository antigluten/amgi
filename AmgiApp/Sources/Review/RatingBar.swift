import SwiftUI
import AmgiTheme
import AnkiKit

/// R11 rating row: four elevated cards — surface background, hairline ring,
/// 3px colored top border, next-interval caption above the label.
struct RatingBar: View {
    let intervals: [Rating: String]
    let showIntervals: Bool
    let isDisabled: Bool
    let onRate: (Rating) -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            ratingCard(.again, label: "Again", color: palette.danger)
            ratingCard(.hard, label: "Hard", color: palette.warning)
            ratingCard(.good, label: "Good", color: palette.positive)
            ratingCard(.easy, label: "Easy", color: palette.info)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func ratingCard(_ rating: Rating, label: String, color: Color) -> some View {
        Button {
            onRate(rating)
        } label: {
            VStack(spacing: 4) {
                if showIntervals {
                    Text(intervals[rating] ?? " ")
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Text(label)
                    .amgiFont(.bodyEmphasis)
                    .foregroundStyle(palette.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(palette.surface)
            .overlay(alignment: .top) {
                color
                    .frame(height: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: AmgiRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AmgiRadius.control, style: .continuous)
                    .strokeBorder(palette.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel("\(label)\(showIntervals ? ", next in \(intervals[rating] ?? "")" : "")")
    }
}

/// Centered post-answer toast — "Good · next in 10m" (R11 answer flow).
struct RatingToastView: View {
    let toast: RatingToast

    @Environment(\.palette) private var palette

    var body: some View {
        Text("\(label) · next in \(toast.interval)")
            .amgiFont(.bodyEmphasis)
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(palette.surfaceElevated, in: Capsule())
            .overlay {
                Capsule().strokeBorder(palette.separator, lineWidth: 1)
            }
    }

    private var label: String {
        switch toast.rating {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }
}

#if DEBUG
#Preview("Rating bar") {
    RatingBar(
        intervals: [.again: "<1m", .hard: "8m", .good: "10m", .easy: "4d"],
        showIntervals: true,
        isDisabled: false,
        onRate: { _ in }
    )
}

#Preview("Toast") {
    RatingToastView(toast: RatingToast(rating: .good, interval: "10m"))
}
#endif
