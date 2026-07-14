public import SwiftUI
public import AmgiTheme
import Darwin

/// Background fill options for `AmgiCard` (and the variants built on it).
/// Top-level so the type identity doesn't shift with `AmgiCard`'s
/// generic `Content` parameter — Swift treats nested types of generic
/// structs as parameterized.
public enum AmgiCardBackground: Sendable {
    case surface
    case surfaceElevated
    case solid(Color)
    case gradient(start: Color, end: Color, angle: Angle = .degrees(135))
}

/// Atomic rounded panel used by every "card" surface in Amgi.
/// Owns background fill, corner radius, drop shadow, and content insets.
/// Higher-level shapes (`AmgiHeroSummary`, future tile / streak cards)
/// compose this primitive — they don't reimplement the chrome.
public struct AmgiCard<Content: View>: View {
    public let background: AmgiCardBackground
    public let shadow: ShadowSpec?
    public let cornerRadius: CGFloat
    public let contentInsets: EdgeInsets
    @ViewBuilder public let content: () -> Content

    @Environment(\.palette) private var palette

    public init(
        background: AmgiCardBackground = .surface,
        shadow: ShadowSpec? = nil,
        cornerRadius: CGFloat = AmgiRadius.hero,
        contentInsets: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.background = background
        self.shadow = shadow
        self.cornerRadius = cornerRadius
        self.contentInsets = contentInsets
        self.content = content
    }

    public var body: some View {
        content()
            .padding(contentInsets)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if palette.elevation == .ring {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(palette.separator, lineWidth: 1)
                }
            }
            .shadow(
                color: .black.opacity(palette.elevation == .ring ? 0 : (shadow?.opacity ?? 0)),
                radius: shadow?.radius ?? 0,
                x: shadow?.dx ?? 0,
                y: shadow?.dy ?? 0
            )
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch background {
        case .surface:
            palette.surface
        case .surfaceElevated:
            palette.surfaceElevated
        case .solid(let color):
            color
        case .gradient(let start, let end, let angle):
            LinearGradient(
                colors: [start, end],
                startPoint: gradientStart(angle: angle),
                endPoint: gradientEnd(angle: angle)
            )
        }
    }

    // Trigonometric convention (NOT CSS):
    // - 0°   → gradient runs leftward (start at right, end at left)
    // - 90°  → gradient runs upward (start at bottom, end at top)
    // - 135° → gradient runs top-right → bottom-left (Amgi default)
    // - 180° → gradient runs rightward (start at left, end at right)
    // This differs from CSS `linear-gradient(135deg, …)` which goes
    // top-left → bottom-right. If you're translating a CSS value, flip
    // the sign or rotate by 180°.
    private func gradientStart(angle: Angle) -> UnitPoint {
        let r = angle.radians
        return UnitPoint(x: 0.5 - 0.5 * cos(r), y: 0.5 - 0.5 * sin(r))
    }

    private func gradientEnd(angle: Angle) -> UnitPoint {
        let r = angle.radians
        return UnitPoint(x: 0.5 + 0.5 * cos(r), y: 0.5 + 0.5 * sin(r))
    }
}
