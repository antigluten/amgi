//
//  AmgiMaterial.swift
//  Theme
//
//  Created by Vladimir Gusev on 31.07.2026.
//

public import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Translucency weight for floating chrome. Maps to a SwiftUI `Material`,
/// but routed through `amgiMaterial(_:in:)` so the Reduce Transparency
/// fallback is decided once instead of per call site.
///
/// On iOS 26 the weight is ignored: Liquid Glass replaces the material
/// outright and has no light/regular axis. The cases describe the pre-26
/// fallback only — don't add a case to express a glass variant.
public enum AmgiMaterialWeight: Sendable {
    /// Lightest — small chips and pills laid over content.
    case light
    /// Default weight for floating controls (circular buttons, capsules).
    case regular

    var material: Material {
        switch self {
        case .light:   .ultraThinMaterial
        case .regular: .regularMaterial
        }
    }
}

public extension View {
    /// Backs a floating surface with a translucent material, falling back to
    /// an opaque palette surface when the user has asked for reduced
    /// transparency.
    ///
    /// A blurred material over arbitrary book or card content is exactly the
    /// case Reduce Transparency exists for — legibility there depends on the
    /// content underneath, which we don't control. The fallback keeps the
    /// same shape and elevation and only drops the blur.
    ///
    /// This is the single seam where translucency is chosen, which is why the
    /// iOS 26 Liquid Glass branch lives here rather than at call sites — the
    /// design conformance guard bans a raw `.glassEffect(` in screen files for
    /// the same reason it bans a raw `.ultraThinMaterial`.
    ///
    /// Pair with `amgiMaterialElevation(_:)`, not `amgiChromeShadow(_:)`:
    /// glass supplies its own edge, so the ring/shadow must drop out with it.
    ///
    /// Pass `interactive: true` for a surface the user can tap or focus — it
    /// makes the glass react to touch (scale, highlight, shimmer) instead of
    /// sitting inert. It is a parameter rather than an `AmgiMaterialWeight`
    /// case because it is orthogonal to weight and has no pre-26 meaning:
    /// a `Material` has no interactive axis, so the fallback ignores it and
    /// pre-26 press feedback stays the caller's job (`.pressScale`).
    func amgiMaterial<S: Shape>(
        _ weight: AmgiMaterialWeight,
        in shape: S,
        interactive: Bool = false
    ) -> some View {
        modifier(AmgiMaterialModifier(weight: weight, shape: shape, interactive: interactive))
    }
}

private struct AmgiMaterialModifier<S: Shape>: ViewModifier {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let weight: AmgiMaterialWeight
    let shape: S
    let interactive: Bool

    /// The non-glass fill, type-erased so Reduce Transparency picks a *value*
    /// instead of selecting between two view structures. That setting is
    /// toggleable while the app runs, so branching on it would swap
    /// `_ConditionalContent` branches and discard the subtree's identity.
    private var fill: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(palette.surfaceElevated)
            : AnyShapeStyle(weight.material)
    }

    func body(content: Content) -> some View {
        // The one structural branch left, and it is not removable: `glassEffect`
        // has no `isEnabled:` in the iOS 26.5 SDK — only `Glass.interactive(_:)`
        // takes a Bool — so glass cannot be applied-and-neutralised the way
        // `fill` is. Glass stays on `content` rather than moving to a
        // `.background` so it keeps its own hit region and can take a
        // `glassEffectID` for morphing.
        //
        // The branch flips only when Reduce Transparency is toggled, and every
        // caller is stateless chrome (a label, an icon, a Button), so losing
        // identity costs nothing today. Don't widen it to wrap content owning
        // `@State` — that's when this becomes the bug it looks like.
        #if os(iOS)
        if #available(iOS 26, *), !reduceTransparency {
            content.glassEffect(.regular.interactive(interactive), in: shape)
        } else {
            content.background(fill, in: shape)
        }
        #else
        content.background(fill, in: shape)
        #endif
    }
}
