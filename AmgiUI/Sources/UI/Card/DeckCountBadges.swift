//
//  DeckCountBadges.swift
//  UI
//
//  Created by Vladimir Gusev on 15.05.2026.
//

public import SwiftUI
import Theme

/// FSRS-colour three-column count badge strip: new (blue) / learning
/// (orange) / review (green). Only non-zero counts are shown. Used in
/// both the Library row and the Study "Up Next" list.
public struct DeckCountBadges: View {
    public let newCount: Int
    public let learnCount: Int
    public let reviewCount: Int

    @Environment(\.palette) private var palette

    public init(newCount: Int, learnCount: Int, reviewCount: Int) {
        self.newCount = newCount
        self.learnCount = learnCount
        self.reviewCount = reviewCount
    }

    public var body: some View {
        HStack(spacing: AmgiSpacing.sm) {
            if newCount > 0 {
                badge(newCount, color: palette.cardStateNew)
            }
            if learnCount > 0 {
                badge(learnCount, color: palette.cardStateLearning)
            }
            if reviewCount > 0 {
                badge(reviewCount, color: palette.cardStateReview)
            }
            if total == 0 {
                Text("\u{2713}")
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .monospacedDigit()
        // The three counts are distinguished only by colour, so VoiceOver
        // got three bare numbers with no roles. Collapse them into one
        // spoken label. This existed on the watch's copy of this component
        // and never reached the iOS one, which ships to far more users.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var total: Int { newCount + learnCount + reviewCount }

    private var accessibilityLabel: String {
        guard total > 0 else { return "No cards due" }
        var parts: [String] = []
        if newCount > 0 { parts.append("\(newCount) new") }
        if learnCount > 0 { parts.append("\(learnCount) learning") }
        if reviewCount > 0 { parts.append("\(reviewCount) to review") }
        return parts.joined(separator: ", ")
    }

    private func badge(_ value: Int, color: Color) -> some View {
        Text("\(value)")
            .amgiFont(size: 16, weight: .semibold, relativeTo: .callout)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .animation(AmgiMotion.quick, value: value)
    }
}
