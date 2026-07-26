public import SwiftUI
import AmgiTheme

/// Library hero card. Built on `AmgiHeroSummary`. Wraps it to supply the
/// streak pill (top-right decoration slot) and the CTA + sparkline
/// (footer slot).
///
/// `data.totalDue == 0` disables the CTA; the rest still renders so
/// the user sees their streak + sparkline.
public struct LibraryHeroCard: View {
    let data: HeroData
    let onStartReview: () -> Void

    @Environment(\.palette) private var palette

    public init(data: HeroData, onStartReview: @escaping () -> Void) {
        self.data = data
        self.onStartReview = onStartReview
    }

    public var body: some View {
        AmgiHeroSummary(
            eyebrow: "Due today",
            bigNumber: "\(data.totalDue)",
            subtitle: subtitleText,
            background: heroGradient,
            decoration: { StreakBadge(days: data.streak) },
            footer: {
                VStack(spacing: 12) {
                    Button(action: onStartReview) {
                        Label("Start today's review", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.white.opacity(0.22))
                    .foregroundStyle(.white)
                    .disabled(data.totalDue == 0)

                    SparklineBars(values: data.last14Days)
                        .frame(height: 28)
                }
            }
        )
    }

    private var subtitleText: String {
        "cards across \(data.deckCount) deck\(data.deckCount == 1 ? "" : "s")"
    }

    private var heroGradient: AmgiCardBackground {
        .gradient(
            start: palette.accent,
            end: Color(red: 0.37, green: 0.36, blue: 0.91), // #5E5CE6 Apple indigo
            angle: .degrees(155)
        )
    }
}

// MARK: - Streak pill

private struct StreakBadge: View {
    let days: Int

    var body: some View {
        if days > 0 {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("\(days)")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(.white)
            .background(.white.opacity(0.22), in: Capsule())
        }
    }
}

// MARK: - 14-day sparkline

private struct SparklineBars: View {
    let values: [Int]

    var body: some View {
        let maxValue = max(values.max() ?? 0, 1)
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(.white.opacity(0.55))
                        .frame(height: max(4, geo.size.height * CGFloat(value) / CGFloat(maxValue)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Populated") {
    LibraryHeroCard(
        data: HeroData(
            totalDue: 680,
            deckCount: 7,
            streak: 36,
            last14Days: [3, 5, 2, 7, 6, 9, 4, 8, 6, 5, 7, 3, 8, 5]
        ),
        onStartReview: {}
    )
    .padding(16)
    .background(Color.gray.opacity(0.12))
    .environment(\.palette, .vividLight)
}

#Preview("Zero due — CTA disabled") {
    LibraryHeroCard(
        data: HeroData(
            totalDue: 0,
            deckCount: 4,
            streak: 12,
            last14Days: [3, 5, 0, 0, 6, 9, 4, 8, 6, 0, 7, 3, 8, 0]
        ),
        onStartReview: {}
    )
    .padding(16)
    .background(Color.gray.opacity(0.12))
    .environment(\.palette, .vividLight)
}

#Preview("Streak zero — badge hidden") {
    LibraryHeroCard(
        data: HeroData(
            totalDue: 42,
            deckCount: 3,
            streak: 0,
            last14Days: Array(repeating: 0, count: 14)
        ),
        onStartReview: {}
    )
    .padding(16)
    .background(Color.gray.opacity(0.12))
    .environment(\.palette, .vividLight)
}
#endif
