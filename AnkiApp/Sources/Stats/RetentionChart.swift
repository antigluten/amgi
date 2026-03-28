import SwiftUI
import AnkiKit

struct RetentionChart: View {
    let rate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Retention Rate (30 days)").font(.headline)

            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(rate * 100))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(retentionColor)
                Text("%")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(retentionColor)
                        .frame(width: geometry.size.width * rate)
                }
            }
            .frame(height: 8)

            Text(retentionDescription).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var retentionColor: Color {
        if rate >= 0.9 { return .green }
        if rate >= 0.8 { return .orange }
        return .red
    }

    private var retentionDescription: String {
        if rate >= 0.9 { return "Excellent retention" }
        if rate >= 0.8 { return "Good retention" }
        if rate >= 0.7 { return "Consider reviewing more frequently" }
        return "Retention needs improvement"
    }
}
