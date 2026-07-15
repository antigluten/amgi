import SwiftUI
import AmgiTheme
import AmgiUI
import Charts
import AnkiKit

struct IntervalsChart: View {
    let intervals: IntervalsBuckets

    @Environment(\.palette) private var palette

    private struct Bucket: Identifiable {
        let id: String
        let label: String
        let count: Int
        let order: Int
    }

    private var buckets: [Bucket] {
        let bucketDefs: [(label: String, range: ClosedRange<Int>)] = [
            ("1d", 0...1),
            ("2d", 2...2),
            ("3-7d", 3...7),
            ("1-2w", 8...14),
            ("2w-1m", 15...30),
            ("1-3m", 31...90),
            ("3-6m", 91...180),
            ("6-12m", 181...365),
            ("1y+", 366...Int.max),
        ]

        return bucketDefs.enumerated().map { index, def in
            let count = intervals.intervals
                .filter { def.range.contains($0.key) }
                .values
                .reduce(0, +)
            return Bucket(id: def.label, label: def.label, count: count, order: index)
        }
        .filter { $0.count > 0 }
    }

    var body: some View {
        AmgiCard(
            background: .surface,
            shadow: palette.shadows.sm,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Review Intervals").amgiFont(.bodyEmphasis)

                if buckets.isEmpty {
                    Text("No interval data").foregroundStyle(.secondary).frame(height: 180)
                } else {
                    Chart(buckets) { bucket in
                        BarMark(
                            x: .value("Interval", bucket.label),
                            y: .value("Cards", bucket.count)
                        )
                        .foregroundStyle(.teal.gradient)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 180)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    IntervalsChart(intervals: .sample)
        .padding()
}
