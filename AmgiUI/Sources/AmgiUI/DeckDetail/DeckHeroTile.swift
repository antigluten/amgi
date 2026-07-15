public import SwiftUI
import AmgiTheme

/// Rounded-square hero tile with a diagonal gradient from `tone` to a
/// 60%-toward-white mix. Renders the deck's resolved glyph (emoji, letter,
/// or monogram) centered, branching on the active palette like Library's
/// `DeckTile`.
///
/// Mirrors the `DeckTile` block in `design/deck.jsx`.
public struct DeckHeroTile: View {
    public let tone: Color
    public let deckName: String
    public let size: CGFloat

    @Environment(\.palette) private var palette

    public init(tone: Color, deckName: String, size: CGFloat = 56) {
        self.tone = tone
        self.deckName = deckName
        self.size = size
    }

    public var body: some View {
        let resolved = DeckTileGlyph.resolve(deckName: deckName, palette: palette)
        return ZStack {
            tileBackground(for: resolved.mode)
            Text(resolved.display)
                .font(.system(size: size * 0.54, weight: glyphWeight(for: resolved.mode)))
                .foregroundStyle(glyphColor(for: resolved.mode))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func tileBackground(for mode: DeckTileGlyph.Resolved.Mode) -> some View {
        switch mode {
        case .emoji:
            gradientTile
        case .letter(let tint):
            RoundedRectangle(cornerRadius: AmgiRadius.hero, style: .continuous).fill(tint)
        case .monogram(let tint):
            RoundedRectangle(cornerRadius: AmgiRadius.hero, style: .continuous)
                .fill(tint.opacity(0.11))
        }
    }

    private var gradientTile: some View {
        RoundedRectangle(cornerRadius: AmgiRadius.hero, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [tone, mixed(tone, with: .white, by: 0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                // Gated: under ring themes the separator ring below is the
                // hairline. Drawing both gives a double edge (R23 final-review Minor).
                if palette.elevation != .ring {
                    RoundedRectangle(cornerRadius: AmgiRadius.hero, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                }
            }
            .shadow(
                color: palette.elevation == .ring ? .clear : Color.black.opacity(0.10),
                radius: 3, x: 0, y: 2
            )
            .overlay {
                if palette.elevation == .ring {
                    RoundedRectangle(cornerRadius: AmgiRadius.hero, style: .continuous)
                        .strokeBorder(palette.separator, lineWidth: 1)
                }
            }
    }

    private func glyphColor(for mode: DeckTileGlyph.Resolved.Mode) -> Color {
        switch mode {
        case .emoji: return palette.textPrimary
        case .letter: return .white
        case .monogram(let tint): return tint
        }
    }

    private func glyphWeight(for mode: DeckTileGlyph.Resolved.Mode) -> Font.Weight {
        if case .emoji = mode { return .regular }
        return .semibold
    }

    private func mixed(_ lhs: Color, with rhs: Color, by fraction: Double) -> Color {
        if #available(iOS 18.0, macOS 15.0, *) {
            return lhs.mix(with: rhs, by: fraction, in: .perceptual)
        } else {
            return lhs
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Hero tile — wheel") {
    HStack(spacing: 12) {
        ForEach(Array(DeckTonePalette.wheel.enumerated()), id: \.offset) { _, tone in
            DeckHeroTile(tone: tone, deckName: "🇰🇷 한국어")
        }
    }
    .padding()
    .environment(\.palette, .vividLight)
}

#Preview("Hero tile — single") {
    DeckHeroTile(tone: .red, deckName: "🇰🇷 한국어")
        .padding()
        .environment(\.palette, .vividLight)
}
#endif
