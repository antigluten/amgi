public import SwiftUI

public enum AmgiFont: Sendable {
    case displayHero       // 34pt semibold, -0.4 tracking
    case sectionHeading    // 24pt semibold, -0.3 tracking
    case cardTitle         // 20pt bold, 0.2 tracking
    case body              // 17pt regular, -0.4 tracking
    case bodyEmphasis      // 17pt semibold, -0.4 tracking
    case caption           // 14pt regular, -0.2 tracking
    case captionBold       // 14pt semibold, -0.2 tracking
    case micro             // 12pt regular, -0.1 tracking
    case serifTitle        // 22pt regular, design: .serif, -0.2 tracking

    /// Resolves to a SwiftUI `Font` for a given user `AppFont` choice.
    /// `serifTitle` is always serif regardless of choice — it's the role's
    /// identity. Every other role flows through `appFont`.
    public func font(for appFont: AppFont) -> Font {
        let design: Font.Design
        switch self {
        case .serifTitle:
            design = .serif
        default:
            design = (appFont == .serif) ? .serif : .default
        }
        return .system(size: size, weight: weight, design: design)
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
        case .displayHero:                    -0.4
        case .sectionHeading:                 -0.3
        case .cardTitle:                       0.2
        case .serifTitle:                     -0.2
        case .body, .bodyEmphasis:            -0.4
        case .caption, .captionBold:          -0.2
        case .micro:                          -0.1
        }
    }
}

private struct AmgiFontModifier: ViewModifier {
    let style: AmgiFont
    @Environment(\.appFont) private var appFont

    func body(content: Content) -> some View {
        content
            .font(style.font(for: appFont))
            .tracking(style.tracking)
    }
}

public extension View {
    func amgiFont(_ style: AmgiFont) -> some View {
        modifier(AmgiFontModifier(style: style))
    }
}
