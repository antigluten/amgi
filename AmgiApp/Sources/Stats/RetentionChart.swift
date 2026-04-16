import SwiftUI
import AnkiProto

struct RetentionChart: View {
    let trueRetention: Anki_Stats_GraphsResponse.TrueRetentionStats

    private struct RetentionRow: Identifiable {
        let id: String
        let label: String
        let youngRate: Double
        let matureRate: Double
        let total: Int
    }

    private var rows: [RetentionRow] {
        func row(_ label: String, _ r: Anki_Stats_GraphsResponse.TrueRetentionStats.TrueRetention) -> RetentionRow {
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
        VStack(alignment: .leading, spacing: 8) {
            Text("True Retention").amgiFont(.bodyEmphasis)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Period").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Young").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Mature").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
                Divider()
                ForEach(rows) { row in
                    GridRow {
                        Text(row.label).font(.caption)
                        retentionBadge(row.youngRate)
                        retentionBadge(row.matureRate)
                    }
                }
            }
        }
        .amgiCard()
    }

    private func retentionBadge(_ rate: Double) -> some View {
        Text(rate > 0 ? "\(Int(rate * 100))%" : "---")
            .font(.caption.monospacedDigit().weight(.medium))
            .foregroundStyle(retentionColor(rate))
    }

    private func retentionColor(_ rate: Double) -> Color {
        if rate <= 0 { return .secondary }
        if rate >= 0.9 { return .green }
        if rate >= 0.8 { return .orange }
        return .red
    }
}
