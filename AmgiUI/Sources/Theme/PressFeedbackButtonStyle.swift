//
//  PressFeedbackButtonStyle.swift
//  Theme
//
//  Created by Vladimir Gusev on 31.07.2026.
//

public import SwiftUI

/// The project's single press-feedback idiom, for buttons whose label already
/// owns its full visual treatment (background, border, padding) and so opts
/// out of the system highlight.
///
/// Scale *and* dim, together: the scale is what reads on a large surface (a
/// deck card, a rating tile), the dim is what reads on a bare glyph or a text
/// chip too small for 4% of scale to be visible. One style covering both is
/// the point — a control that looks like another control has to feel like it,
/// and the app previously had a scale idiom in the component library and a
/// dim idiom in the screens.
///
/// The feedback starts on press-*down*, and the spring means a press aborted
/// mid-travel reverses from wherever the scale currently is rather than
/// snapping back from its target.
public struct PressFeedbackButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.amgiPressFeedback(configuration.isPressed)
    }
}

public extension View {
    /// The press treatment itself, for `ButtonStyle`s that also draw their own
    /// chrome and so can't just adopt `.pressScale` wholesale.
    func amgiPressFeedback(_ isPressed: Bool) -> some View {
        scaleEffect(isPressed ? 0.96 : 1)
            .opacity(isPressed ? 0.9 : 1)
            .animation(AmgiMotion.quick, value: isPressed)
    }
}

public extension ButtonStyle where Self == PressFeedbackButtonStyle {
    static var pressScale: PressFeedbackButtonStyle { PressFeedbackButtonStyle() }
}
