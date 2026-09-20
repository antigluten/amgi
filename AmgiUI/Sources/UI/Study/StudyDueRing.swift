//
//  StudyDueRing.swift
//  UI
//
//  Created by Vladimir Gusev on 15.05.2026.
//

public import SwiftUI
import Theme

public struct StudyDueRing: View {
    public let summary: StudySummaryData

    @Environment(\.palette) private var palette

    private let ringSize: CGFloat = 200
    private let lineWidth: CGFloat = 18
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 44

    public init(summary: StudySummaryData) {
        self.summary = summary
    }

    public var body: some View {
        ZStack {
            trackCircle
            accentArc
            centerContent
        }
        .frame(width: ringSize, height: ringSize)
    }

    // MARK: - Track

    private var trackCircle: some View {
        Circle()
            .stroke(palette.separator, lineWidth: lineWidth)
            .frame(width: ringSize, height: ringSize)
    }

    // MARK: - Accent arc (design-literal: empty on landing)

    private var accentArc: some View {
        Circle()
            .trim(from: 0, to: 0)
            .stroke(palette.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: ringSize, height: ringSize)
    }

    // MARK: - Centre text

    private var centerContent: some View {
        VStack(spacing: 2) {
            Text("DUE NOW")
                .amgiFont(.micro)
                .foregroundStyle(palette.textSecondary)

            Text("\(summary.totalDue)")
                .font(.system(size: heroSize, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(palette.textPrimary)
                .contentTransition(.numericText())

            Text(sublineLabel)
                .amgiFont(.micro)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: ringSize - lineWidth * 2 - 16)
        }
    }

    private var sublineLabel: String {
        guard summary.totalDue > 0 else { return "Nothing due today" }
        let n = summary.deckCount
        return "across \(n) deck\(n == 1 ? "" : "s")"
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Busy day") {
    StudyDueRing(summary: StudySummaryData(
        totalDue: 187,
        newCount: 40,
        learnCount: 72,
        reviewCount: 75,
        todayLabel: "Today",
        subtitleLabel: "Wednesday · 4 decks due",
        deckCount: 4
    ))
    .padding(32)
    .environment(\.palette, .vividLight)
}

#Preview("All done") {
    StudyDueRing(summary: StudySummaryData(
        totalDue: 0,
        newCount: 0,
        learnCount: 0,
        reviewCount: 0,
        todayLabel: "Today",
        subtitleLabel: "Wednesday",
        deckCount: 0
    ))
    .padding(32)
    .environment(\.palette, .vividLight)
}

#Preview("Dark — busy") {
    StudyDueRing(summary: StudySummaryData(
        totalDue: 42,
        newCount: 10,
        learnCount: 8,
        reviewCount: 24,
        todayLabel: "Today",
        subtitleLabel: "Thursday · 3 decks due",
        deckCount: 3
    ))
    .padding(32)
    .background(Color.black)
    .environment(\.palette, .vividDark)
}
#endif
