//
//  DeckHero.swift
//  UI
//
//  Created by Vladimir Gusev on 16.05.2026.
//

public import SwiftUI
import Theme

/// Hero block at the top of the deck-detail screen: gradient tile +
/// large title + Custom Study chip + subtitle line.
public struct DeckHero: View {
    public let title: String
    public let subtitle: String
    public let tone: Color
    public let deckName: String
    public let isFiltered: Bool

    @Environment(\.palette) private var palette

    public init(
        title: String,
        subtitle: String,
        tone: Color,
        deckName: String,
        isFiltered: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.deckName = deckName
        self.isFiltered = isFiltered
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DeckHeroTile(tone: tone, deckName: deckName)
                .padding(.bottom, 8)
            titleRow
            subtitleText
        }
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .amgiFont(size: 32, weight: .bold)
                .lineSpacing(2)
                .foregroundStyle(palette.textPrimary)
            if isFiltered {
                customStudyChip
            }
        }
        .padding(.top, 4)
    }

    private var customStudyChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.caption.weight(.semibold))
            Text("Custom Study")
                .amgiFont(size: 11, weight: .semibold)
        }
        .foregroundStyle(palette.background)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(palette.customStudyBadge, in: Capsule())
        .accessibilityLabel("Custom study deck")
    }

    private var subtitleText: some View {
        Text(subtitle)
            .amgiFont(size: 15, weight: .regular, tracking: -0.24)
            .foregroundStyle(palette.textSecondary)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Hero — standard") {
    DeckHero(
        title: "한국어",
        subtitle: "Last studied today · 32-day streak",
        tone: .red,
        deckName: "🇰🇷 한국어",
        isFiltered: false
    )
    .padding()
    .environment(\.palette, .vividLight)
}

#Preview("Hero — filtered chip") {
    DeckHero(
        title: "한국어",
        subtitle: "Last studied today · 32-day streak",
        tone: .red,
        deckName: "🇰🇷 한국어",
        isFiltered: true
    )
    .padding()
    .environment(\.palette, .vividLight)
}

#Preview("Hero — empty deck copy") {
    DeckHero(
        title: "Fresh deck",
        subtitle: "No cards yet · Add some to start studying",
        tone: .blue,
        deckName: "📚 Fresh deck",
        isFiltered: false
    )
    .padding()
    .environment(\.palette, .vividLight)
}
#endif
