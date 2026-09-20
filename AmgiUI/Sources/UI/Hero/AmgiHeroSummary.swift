//
//  AmgiHeroSummary.swift
//  UI
//
//  Created by Vladimir Gusev on 14.05.2026.
//

public import SwiftUI
import Theme

/// Library-hero card: gradient background, eyebrow + big numeral +
/// subtitle stacked on the left, optional decoration (sparkline/badge)
/// trailing, optional footer (CTA button or extra row). Foreground text
/// is white — caller picks a background that has enough contrast.
///
/// Built on `AmgiCard` for chrome (corner + shadow + padding). Other
/// surfaces (Deck-detail tile, Stats streak) compose `AmgiCard` directly
/// rather than extend this variant.
public struct AmgiHeroSummary<Decoration: View, Footer: View>: View {
    public let eyebrow: String?
    public let bigNumber: String
    public let subtitle: String?
    public let background: AmgiCardBackground
    @ViewBuilder public let decoration: () -> Decoration
    @ViewBuilder public let footer: () -> Footer

    @Environment(\.palette) private var palette

    public init(
        eyebrow: String?,
        bigNumber: String,
        subtitle: String?,
        background: AmgiCardBackground,
        @ViewBuilder decoration: @escaping () -> Decoration,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.eyebrow = eyebrow
        self.bigNumber = bigNumber
        self.subtitle = subtitle
        self.background = background
        self.decoration = decoration
        self.footer = footer
    }

    public var body: some View {
        AmgiCard(background: background, shadow: palette.shadows.md) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let eyebrow {
                            Text(eyebrow.uppercased())
                                .amgiFont(size: 13, weight: .semibold, tracking: 0.4, relativeTo: .footnote)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Text(bigNumber)
                            .amgiFont(size: 56, weight: .bold, tracking: -1.2, relativeTo: .largeTitle)
                            .foregroundStyle(.white)
                        if let subtitle {
                            Text(subtitle)
                                .amgiFont(size: 15, weight: .regular, relativeTo: .subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 12)
                    decoration()
                }
                footer()
            }
        }
    }
}
