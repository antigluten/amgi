//
//  AmgiModifiers.swift
//  UI
//
//  Created by Vladimir Gusev on 13.04.2026.
//

public import SwiftUI
public import Theme

// MARK: - Button Styles

public struct AmgiPrimaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .amgiFont(.body)
            .foregroundStyle(.white)
            .padding(.vertical, AmgiSpacing.sm)
            .padding(.horizontal, 20)
            .background(palette.accent, in: Capsule())
            .amgiPressFeedback(configuration.isPressed)
    }
}

public struct AmgiSecondaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .amgiFont(.body)
            .foregroundStyle(palette.accent)
            .padding(.vertical, AmgiSpacing.sm)
            .padding(.horizontal, 20)
            .background(
                Capsule().stroke(palette.accent, lineWidth: 1)
            )
            .amgiPressFeedback(configuration.isPressed)
    }
}

// MARK: - Status Tone

public enum AmgiStatusTone {
    case accent
    case positive
    case warning
    case danger
    case info
    case neutral

    fileprivate func foregroundColor(_ palette: Palette) -> Color {
        switch self {
        case .accent:   return palette.accent
        case .positive: return palette.positive
        case .warning:  return palette.warning
        case .danger:   return palette.danger
        case .info:     return palette.info
        case .neutral:  return palette.textSecondary
        }
    }

    fileprivate func toolbarForegroundColor(_ palette: Palette) -> Color {
        switch self {
        case .neutral: return palette.textPrimary
        default:       return foregroundColor(palette)
        }
    }
}

// MARK: - Status Message (centered Label + caption, used for empty states)

public struct AmgiStatusMessageView: View {
    @Environment(\.palette) private var palette
    let title: String
    let message: String
    let systemImage: String
    let tone: AmgiStatusTone

    public init(title: String, message: String, systemImage: String, tone: AmgiStatusTone) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tone = tone
    }

    public var body: some View {
        VStack(spacing: AmgiSpacing.md) {
            Label(title, systemImage: systemImage)
                .amgiFont(.bodyEmphasis)
                .foregroundStyle(tone.foregroundColor(palette))

            Text(message)
                .amgiFont(.caption)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, AmgiSpacing.lg)
    }
}

// MARK: - Toolbar / Capsule / Status modifiers

extension View {
    /// Styles a toolbar icon's chip chrome (size, background, border). Content-only —
    /// pair the enclosing `Button` with `.buttonStyle(.pressScale)` for
    /// press feedback; a `ViewModifier` applied to the label can't see `isPressed`.
    public func amgiToolbarIconButton(size: CGFloat = 32) -> some View {
        modifier(AmgiToolbarIconButtonModifier(size: size))
    }

    public func amgiToolbarTextButton(tone: AmgiStatusTone = .accent) -> some View {
        modifier(AmgiToolbarTextButtonModifier(tone: tone))
    }

    public func amgiCapsuleControl(horizontalPadding: CGFloat = AmgiSpacing.sm, verticalPadding: CGFloat = AmgiSpacing.sm) -> some View {
        modifier(AmgiCapsuleControlModifier(horizontalPadding: horizontalPadding, verticalPadding: verticalPadding))
    }

    public func amgiStatusText(_ tone: AmgiStatusTone, font: AmgiFont = .captionBold) -> some View {
        modifier(AmgiStatusTextModifier(tone: tone, font: font))
    }
}

private struct AmgiToolbarIconButtonModifier: ViewModifier {
    @Environment(\.palette) private var palette
    let size: CGFloat
    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .foregroundStyle(palette.textPrimary)
            .background(palette.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: AmgiRadius.control, style: .continuous)
                    .stroke(palette.border.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AmgiRadius.control, style: .continuous))
    }
}

private struct AmgiToolbarTextButtonModifier: ViewModifier {
    @Environment(\.palette) private var palette
    let tone: AmgiStatusTone
    func body(content: Content) -> some View {
        content
            .tint(tone.toolbarForegroundColor(palette))
            .foregroundStyle(tone.toolbarForegroundColor(palette))
    }
}

private struct AmgiCapsuleControlModifier: ViewModifier {
    @Environment(\.palette) private var palette
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(palette.surfaceElevated)
            .overlay(
                Capsule().stroke(palette.border.opacity(0.28), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

private struct AmgiStatusTextModifier: ViewModifier {
    @Environment(\.palette) private var palette
    let tone: AmgiStatusTone
    let font: AmgiFont
    func body(content: Content) -> some View {
        content
            .amgiFont(font)
            .foregroundStyle(tone.foregroundColor(palette))
    }
}

// MARK: - Chrome elevation shadow (ring vs shadow)

extension View {
    /// Floating chrome (capsule/circle buttons, cover art) that needs the
    /// same ring-vs-shadow elevation switch `AmgiCard` uses internally, but
    /// doesn't fit `AmgiCard`'s padding+background shape. The caller still
    /// owns its own `.background(_:in:)`; this only adds the ring overlay
    /// (under `.ring` elevation) or the drop shadow (under `.shadow`
    /// elevation), clipped to `shape`.
    ///
    /// Lives here rather than at the call site because the design
    /// conformance guard bans raw `.shadow(` in every screen file — this
    /// is the one mechanism other views delegate to.
    ///
    /// `isEnabled: false` keeps the modifier applied and neutralises it, rather
    /// than letting callers drop it — see `AmgiChromeShadowModifier`.
    public func amgiChromeShadow<S: InsettableShape>(
        _ shape: S,
        radius: CGFloat = 4,
        x: CGFloat = 0,
        y: CGFloat = 2,
        opacity: Double = 0.08,
        isEnabled: Bool = true
    ) -> some View {
        modifier(
            AmgiChromeShadowModifier(
                shape: shape, radius: radius, x: x, y: y, opacity: opacity, isEnabled: isEnabled
            )
        )
    }

    /// `amgiChromeShadow`, but skipped on iOS 26 — the elevation partner for
    /// surfaces backed by `amgiMaterial(_:in:)`.
    ///
    /// On iOS 26 that surface is Liquid Glass, which draws its own edge and
    /// shading. Layering the elevation ring or drop shadow on top of it
    /// double-draws the boundary and makes the control read as a sticker
    /// pasted over the content rather than a lens onto it. Surfaces that are
    /// *not* material-backed (cover art, the stats tooltip) keep calling
    /// `amgiChromeShadow` directly — they need their elevation on every OS.
    public func amgiMaterialElevation<S: InsettableShape>(
        _ shape: S,
        radius: CGFloat = 4,
        x: CGFloat = 0,
        y: CGFloat = 2,
        opacity: Double = 0.08
    ) -> some View {
        modifier(AmgiMaterialElevationModifier(shape: shape, radius: radius, x: x, y: y, opacity: opacity))
    }
}

private struct AmgiMaterialElevationModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    let opacity: Double

    /// Mirrors `amgiMaterial`'s decision: Reduce Transparency swaps glass for
    /// an opaque surface even on iOS 26, and an opaque chip with no edge is
    /// exactly the legibility problem that setting exists to fix — so the ring
    /// comes back with it. Only drop elevation where glass really drew.
    ///
    /// Both inputs collapse to a `Bool` here, so the elevation is switched by
    /// *value*. Nothing in this file selects between two view structures.
    private var isGlassBacked: Bool {
        guard #available(iOS 26, *) else { return false }
        return !reduceTransparency
    }

    func body(content: Content) -> some View {
        content.amgiChromeShadow(
            shape, radius: radius, x: x, y: y, opacity: opacity, isEnabled: !isGlassBacked
        )
    }
}

private struct AmgiChromeShadowModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.palette) private var palette
    let shape: S
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    let opacity: Double
    let isEnabled: Bool

    private var isRing: Bool { palette.elevation == .ring }

    private var ringColor: Color {
        isEnabled && isRing ? palette.separator : .clear
    }

    private var shadowColor: Color {
        isEnabled && !isRing ? .black.opacity(opacity) : .clear
    }

    func body(content: Content) -> some View {
        // Ring and shadow are both applied unconditionally and neutralised with
        // `.clear`, rather than an `if` choosing which to attach. The shadow
        // already worked this way; the overlay didn't, and `palette.elevation`
        // flips whenever the user picks a theme — so that `if` was putting
        // `content` inside a `_ConditionalContent` whose branch changes at
        // runtime, discarding the subtree's identity for a decorative change.
        content
            .overlay { shape.strokeBorder(ringColor, lineWidth: 1) }
            .shadow(color: shadowColor, radius: radius, x: x, y: y)
    }
}
