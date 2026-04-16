import SwiftUI
import Charts
import AnkiProto

struct IntervalsChart: View {
    let intervals: Anki_Stats_GraphsResponse.Intervals

    private struct Bucket: Identifiable {
        let id: String
        let label: String
        let count: Int
        let order: Int
    }

    private var buckets: [Bucket] {
        let bucketDefs: [(label: String, range: ClosedRange<UInt32>)] = [
            ("1d", 0...1),
            ("2d", 2...2),
            ("3-7d", 3...7),
            ("1-2w", 8...14),
            ("2w-1m", 15...30),
            ("1-3m", 31...90),
            ("3-6m", 91...180),
            ("6-12m", 181...365),
            ("1y+", 366...UInt32.max),
        ]

        return bucketDefs.enumerated().map { index, def in
            let count = intervals.intervals
                .filter { def.range.contains($0.key) }
                .values
                .reduce(0, +)
            return Bucket(id: def.label, label: def.label, count: Int(count), order: index)
        }
        .filter { $0.count > 0 }
    }

    var body: some View {
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
        .amgiCard()
    }
}
