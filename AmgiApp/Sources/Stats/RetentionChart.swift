import SwiftUI
import AmgiTheme
import AmgiUI
import AnkiKit

struct RetentionChart: View {
    let trueRetention: TrueRetentionStats

    @Environment(\.palette) private var palette

    private struct RetentionRow: Identifiable {
        let id: String
        let label: String
        let youngRate: Double
        let matureRate: Double
        let total: Int
    }

    private var rows: [RetentionRow] {
        func row(_ label: String, _ r: TrueRetentionStats.TrueRetention) -> RetentionRow {
            let youngTotal = r.youngPassed + r.youngFailed
            let matureTotal = r.maturePassed + r.matureFailed
            let youngRate = youngTotal > 0 ? Double(r.youngPassed) / Double(youngTotal) : 0
            let matureRate = matureTotal > 0 ? Double(r.maturePassed) / Double(matureTotal) : 0
            return RetentionRow(
                id: label,
                label: label,
                youngRate: youngRate,
                matureRate: matureRate,
                total: Int(youngTotal + matureTotal)
            )
        }
        return [
            row("Today", trueRetention.today),
            row("Yesterday", trueRetention.yesterday),
            row("Week", trueRetention.week),
            row("Month", trueRetention.month),
            row("Year", trueRetention.year),
            row("All Time", trueRetention.allTime),
        ]
    }

    var body: some View {
        AmgiCard(
            background: .surface,
            shadow: palette.shadows.sm,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("True Retention").amgiFont(.bodyEmphasis)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Period").amgiFont(.captionBold).foregroundStyle(palette.textSecondary)
                        Text("Young").amgiFont(.captionBold).foregroundStyle(palette.textSecondary)
                        Text("Mature").amgiFont(.captionBold).foregroundStyle(palette.textSecondary)
                    }
                    Divider()
                    ForEach(rows) { row in
                        GridRow {
                            Text(row.label).amgiFont(.caption)
                            retentionBadge(row.youngRate)
                            retentionBadge(row.matureRate)
                        }
                    }
                }
            }
        }
    }
}

private extension RetentionChart {
    func retentionBadge(_ rate: Double) -> some View {
        Text(rate > 0 ? "\(Int(rate * 100))%" : "---")
            .amgiFont(.captionBold)
            .monospacedDigit()
            .foregroundStyle(retentionColor(rate))
    }

    func retentionColor(_ rate: Double) -> Color {
        if rate <= 0 { return palette.textSecondary }
        if rate >= 0.9 { return palette.positive }
        if rate >= 0.8 { return palette.warning }
        return palette.danger
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    RetentionChart(trueRetention: .sample)
        .padding()
}
#endif
