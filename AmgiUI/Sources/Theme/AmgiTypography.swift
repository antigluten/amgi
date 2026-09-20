//
//  AmgiTypography.swift
//  Theme
//
//  Created by Vladimir Gusev on 13.04.2026.
//

public import SwiftUI

public enum AmgiFont: Sendable {
    case displayHero       // 34pt semibold, -0.6 tracking
    case sectionHeading    // 24pt semibold, -0.3 tracking
    case cardTitle         // 20pt bold, 0.2 tracking
    case body              // 17pt regular, -0.4 tracking
    case bodyEmphasis      // 17pt semibold, -0.4 tracking
    case caption           // 14pt regular, -0.2 tracking
    case captionBold       // 14pt semibold, -0.2 tracking
    case micro             // 12pt regular, -0.1 tracking
    case serifTitle        // 22pt regular, design: .serif, -0.2 tracking

    /// Resolves to a SwiftUI `Font` for a given user `AppFont` choice at an
    /// explicit point size.
    ///
    /// Call sites should prefer `.amgiFont(_:)`, which scales `size` with the
    /// user's Dynamic Type setting before calling this. Passing the raw
    /// `size` here pins the text at the design size and opts that text out of
    /// Dynamic Type.
    public func font(for appFont: AppFont, size: CGFloat, variant: AmgiFontVariant = .standard) -> Font {
        let design: Font.Design
        switch (self, variant) {
        case (_, .monospaced):
            design = .monospaced
        case (.serifTitle, _):
            design = .serif
        default:
            design = (appFont == .serif) ? .serif : .default
        }
        let font = Font.system(size: size, weight: weight, design: design)
        return variant == .monospacedDigits ? font.monospacedDigit() : font
    }

    public var size: CGFloat {
        switch self {
        case .displayHero:    34
        case .sectionHeading: 24
        case .cardTitle:      20
        case .serifTitle:     22
        case .body, .bodyEmphasis: 17
        case .caption, .captionBold: 14
        case .micro:          12
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .displayHero, .sectionHeading: .semibold
        case .cardTitle:                    .bold
        case .body, .caption, .micro, .serifTitle: .regular
        case .bodyEmphasis, .captionBold:   .semibold
        }
    }

    public var tracking: CGFloat {
        switch self {
        case .displayHero:                    -0.6
        case .sectionHeading:                 -0.3
        case .cardTitle:                       0.2
        case .serifTitle:                     -0.2
        case .body, .bodyEmphasis:            -0.4
        case .caption, .captionBold:          -0.2
        case .micro:                          -0.1
        }
    }

    /// The system text style this role scales against.
    ///
    /// Each role keeps its bespoke point size — the text style only supplies
    /// the *scaling curve*, so a role tracks the user's Dynamic Type setting
    /// at the rate Apple tuned for text of that size. Picked as the nearest
    /// system style by size, so the curve matches the role's optical weight.
    public var textStyle: Font.TextStyle {
        switch self {
        case .displayHero:                   .largeTitle   // 34
        case .sectionHeading:                .title2       // 22
        case .serifTitle:                    .title2       // 22
        case .cardTitle:                     .title3       // 20
        case .body, .bodyEmphasis:           .body         // 17
        case .caption, .captionBold:         .footnote     // 13
        case .micro:                         .caption      // 12
        }
    }
}

/// Face variations that don't warrant their own role — the size, weight, and
/// tracking still come from the `AmgiFont` role.
public enum AmgiFontVariant: Sendable, Equatable {
    /// The role as declared.
    case standard
    /// Proportional face with tabular figures. For numbers that update in
    /// place (page counters, timers, stats) so the layout doesn't jitter.
    case monospacedDigits
    /// Full monospaced design. For code — template source, search syntax.
    case monospaced
}

public extension View {
    func amgiFont(_ style: AmgiFont, _ variant: AmgiFontVariant = .standard) -> some View {
        modifier(AmgiFontModifier(style: style, variant: variant))
    }

    /// One-off text sizing that still resolves `design` from `\.appFont` and
    /// still scales with Dynamic Type.
    ///
    /// Prefer `.amgiFont(_:)` when an existing role's size/weight fits —
    /// `relativeTo` here is a guess, whereas a role's is considered.
    func amgiFont(
        size: CGFloat,
        weight: Font.Weight,
        tracking: CGFloat = 0,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(
            AmgiCustomFontModifier(
                size: size, weight: weight, tracking: tracking, textStyle: textStyle
            )
        )
    }
}

/// Scales a design point size against the user's Dynamic Type setting, and
/// scales `tracking` by the same ratio.
///
/// Tracking has to move with the size or it silently changes meaning: -0.4pt
/// is a deliberate tightening at 17pt and a barely-there nudge at 34pt. Apple
/// varies tracking by size for exactly this reason, so the ratio keeps the
/// role's intent intact across the whole Dynamic Type range.
private struct ScaledType {
    let size: CGFloat
    let tracking: CGFloat

    init(designSize: CGFloat, scaledSize: CGFloat, tracking: CGFloat) {
        self.size = scaledSize
        self.tracking = designSize > 0 ? tracking * (scaledSize / designSize) : tracking
    }
}

private struct AmgiFontModifier: ViewModifier {
    let style: AmgiFont
    let variant: AmgiFontVariant
    @Environment(\.appFont) private var appFont
    @ScaledMetric private var scaledSize: CGFloat

    init(style: AmgiFont, variant: AmgiFontVariant) {
        self.style = style
        self.variant = variant
        _scaledSize = ScaledMetric(wrappedValue: style.size, relativeTo: style.textStyle)
    }

    func body(content: Content) -> some View {
        let scaled = ScaledType(
            designSize: style.size, scaledSize: scaledSize, tracking: style.tracking
        )
        content
            .font(style.font(for: appFont, size: scaled.size, variant: variant))
            .tracking(scaled.tracking)
    }
}

private struct AmgiCustomFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let tracking: CGFloat
    @Environment(\.appFont) private var appFont
    @ScaledMetric private var scaledSize: CGFloat

    init(size: CGFloat, weight: Font.Weight, tracking: CGFloat, textStyle: Font.TextStyle) {
        self.size = size
        self.weight = weight
        self.tracking = tracking
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
    }

    func body(content: Content) -> some View {
        let scaled = ScaledType(
            designSize: size, scaledSize: scaledSize, tracking: tracking
        )
        content
            .font(.system(
                size: scaled.size,
                weight: weight,
                design: appFont == .serif ? .serif : .default
            ))
            .tracking(scaled.tracking)
    }
}
