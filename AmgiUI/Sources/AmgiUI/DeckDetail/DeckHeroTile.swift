public import SwiftUI
import AmgiTheme

/// Rounded-square hero tile with a diagonal gradient from `tone` to a
/// 60%-toward-white mix. Renders the deck's emoji/flag glyph centered.
///
/// Mirrors the `DeckTile` block in `design/deck.jsx`.
public struct DeckHeroTile: View {
    public let tone: Color
    public let glyph: String
    public let size: CGFloat

    public init(tone: Color, glyph: String, size: CGFloat = 56) {
        self.tone = tone
        self.glyph = glyph
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tone, mixed(tone, with: .white, by: 0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 2)

            Text(glyph)
                .font(.system(size: size * 0.54))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
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
            DeckHeroTile(tone: tone, glyph: "🇰🇷")
        }
    }
    .padding()
    .environment(\.palette, .vividLight)
}

#Preview("Hero tile — single") {
    DeckHeroTile(tone: .red, glyph: "🇰🇷")
        .padding()
        .environment(\.palette, .vividLight)
}
#endif
