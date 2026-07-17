import SwiftUI
import AmgiTheme

// MARK: - Section Background

extension View {
    func amgiSectionBackground() -> some View {
        modifier(AmgiSectionBackgroundModifier())
    }
}

private struct AmgiSectionBackgroundModifier: ViewModifier {
    @Environment(\.palette) private var palette
    func body(content: Content) -> some View {
        content.background(palette.background)
    }
}

// MARK: - Button Styles

struct AmgiPrimaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .amgiFont(.body)
            .foregroundStyle(.white)
            .padding(.vertical, AmgiSpacing.sm)
            .padding(.horizontal, 20)
            .background(palette.accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct AmgiSecondaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .amgiFont(.body)
            .foregroundStyle(palette.accent)
            .padding(.vertical, AmgiSpacing.sm)
            .padding(.horizontal, 20)
            .background(
                Capsule().stroke(palette.accent, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

// MARK: - Status Tone

enum AmgiStatusTone {
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

    fileprivate func backgroundColor(_ palette: Palette) -> Color {
        switch self {
        case .accent:   return palette.accent.opacity(0.12)
        case .positive: return palette.positive.opacity(0.14)
        case .warning:  return palette.warning.opacity(0.16)
        case .danger:   return palette.danger.opacity(0.14)
        case .info:     return palette.info.opacity(0.14)
        case .neutral:  return palette.surface
        }
    }

    fileprivate func borderColor(_ palette: Palette) -> Color {
        switch self {
        case .neutral: return palette.border.opacity(0.32)
        default:       return foregroundColor(palette).opacity(0.28)
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

struct AmgiStatusMessageView: View {
    @Environment(\.palette) private var palette
    let title: String
    let message: String
    let systemImage: String
    let tone: AmgiStatusTone

    var body: some View {
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
    func amgiToolbarIconButton(size: CGFloat = 32) -> some View {
        modifier(AmgiToolbarIconButtonModifier(size: size))
    }

    func amgiToolbarTextButton(tone: AmgiStatusTone = .accent) -> some View {
        modifier(AmgiToolbarTextButtonModifier(tone: tone))
    }

    func amgiCapsuleControl(horizontalPadding: CGFloat = 10, verticalPadding: CGFloat = 6) -> some View {
        modifier(AmgiCapsuleControlModifier(horizontalPadding: horizontalPadding, verticalPadding: verticalPadding))
    }

    func amgiStatusBadge(_ tone: AmgiStatusTone, horizontalPadding: CGFloat = 8, verticalPadding: CGFloat = 4) -> some View {
        modifier(AmgiStatusBadgeModifier(tone: tone, horizontalPadding: horizontalPadding, verticalPadding: verticalPadding))
    }

    func amgiStatusPanel(_ tone: AmgiStatusTone, elevated: Bool = false) -> some View {
        modifier(AmgiStatusPanelModifier(tone: tone, elevated: elevated))
    }

    func amgiSegmentedPicker() -> some View {
        pickerStyle(.segmented)
    }

    func amgiStatusText(_ tone: AmgiStatusTone, font: AmgiFont = .captionBold) -> some View {
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

private struct AmgiStatusBadgeModifier: ViewModifier {
    @Environment(\.palette) private var palette
    let tone: AmgiStatusTone
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    func body(content: Content) -> some View {
        content
            .amgiFont(.captionBold)
            .foregroundStyle(tone.foregroundColor(palette))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(tone.backgroundColor(palette))
            .overlay(
                Capsule().stroke(tone.borderColor(palette), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

private struct AmgiStatusPanelModifier: ViewModifier {
    @Environment(\.palette) private var palette
    let tone: AmgiStatusTone
    let elevated: Bool
    func body(content: Content) -> some View {
        content
            .padding(AmgiSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AmgiRadius.inset, style: .continuous)
                    .fill(palette.surfaceElevated)
            )
            .background(
                RoundedRectangle(cornerRadius: AmgiRadius.inset, style: .continuous)
                    .fill(tone.backgroundColor(palette))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AmgiRadius.inset, style: .continuous)
                    .stroke(tone.borderColor(palette), lineWidth: 1)
            )
            .shadow(
                color: (elevated && palette.elevation != .ring)
                    ? .black.opacity(palette.shadows.md.opacity)
                    : .clear,
                radius: palette.shadows.md.radius,
                x: palette.shadows.md.dx,
                y: palette.shadows.md.dy
            )
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
    /// is the one mechanism other views delegate to, mirroring
    /// `AmgiStatusPanelModifier` above.
    func amgiChromeShadow<S: InsettableShape>(
        _ shape: S,
        radius: CGFloat = 4,
        x: CGFloat = 0,
        y: CGFloat = 2,
        opacity: Double = 0.08
    ) -> some View {
        modifier(AmgiChromeShadowModifier(shape: shape, radius: radius, x: x, y: y, opacity: opacity))
    }
}

private struct AmgiChromeShadowModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.palette) private var palette
    let shape: S
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .overlay {
                if palette.elevation == .ring {
                    shape.strokeBorder(palette.separator, lineWidth: 1)
                }
            }
            .shadow(
                color: palette.elevation == .ring ? .clear : .black.opacity(opacity),
                radius: radius, x: x, y: y
            )
    }
}
