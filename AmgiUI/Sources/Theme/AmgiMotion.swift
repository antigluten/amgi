//
//  AmgiMotion.swift
//  Theme
//
//  Created by Vladimir Gusev on 31.07.2026.
//

public import SwiftUI

#if os(iOS)
import UIKit
#endif

/// The project's motion vocabulary.
///
/// Every animated state change in the app resolves through here rather than
/// spelling its own `.easeInOut(duration:)`. Two reasons:
///
/// 1. **Springs, not curves.** A fixed-duration curve can't be interrupted
///    mid-flight, can't start from the value currently on screen, and can't
///    inherit a gesture's velocity. A spring does all three for free — a new
///    target just re-aims the same continuous motion. `standard` is
///    critically damped (no overshoot); `momentum` carries a little bounce
///    and is reserved for motion that follows a flick, throw, or arrival
///    from offscreen, where overshoot reads as physics rather than as decor.
/// 2. **Reduce Motion is handled once.** Under the accessibility setting every
///    role degrades to a short cross-fade, so no call site has to remember.
///
/// `duration` here is a spring's *response* — how fast it converges — not a
/// fixed runtime. The motion settles when the physics say so.
@MainActor
public enum AmgiMotion {

    /// Critically damped, no overshoot. The default for any state change:
    /// content swaps, banner reveals, layout shifts, progress.
    public static var standard: Animation {
        resolve(.smooth(duration: 0.35))
    }

    /// Same character as `standard`, tuned for small controls whose feedback
    /// must feel immediate — press states, chips, toggles.
    public static var quick: Animation {
        resolve(.smooth(duration: 0.2))
    }

    /// Slight overshoot. Only for motion that follows momentum — something
    /// flicked, thrown, or sliding in from an edge. Overshoot on a plain fade
    /// reads as noise; overshoot on a thrown object reads as mass.
    public static var momentum: Animation {
        resolve(.snappy(duration: 0.35, extraBounce: 0.1))
    }

    /// A slide-and-fade that collapses to a plain cross-fade under Reduce
    /// Motion — the setting asks for a non-vestibular equivalent, not for
    /// the same travel played faster.
    public static func slide(from edge: Edge) -> AnyTransition {
        prefersReducedMotion
            ? .opacity
            : .move(edge: edge).combined(with: .opacity)
    }

    /// Cross-dissolve with a small settle-in scale. Used where one piece of
    /// content replaces another in place and the scale telegraphs "this
    /// arrived" without moving the layout.
    public static var reveal: AnyTransition {
        prefersReducedMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.96))
    }

    /// Whether the user has asked for reduced motion.
    ///
    /// Read from the platform global rather than `\.accessibilityReduceMotion`
    /// so that `withAnimation` inside an `@Observable` model — which has no
    /// environment — resolves the same way a view body does.
    ///
    /// ponytail: not reactive; a change taken while the app is foregrounded
    /// applies at the next view update rather than immediately. Observe
    /// `UIAccessibility.reduceMotionStatusDidChangeNotification` if that
    /// ever matters.
    public static var prefersReducedMotion: Bool {
        #if os(iOS)
        UIAccessibility.isReduceMotionEnabled
        #else
        false
        #endif
    }

    private static func resolve(_ spring: Animation) -> Animation {
        prefersReducedMotion ? .easeOut(duration: 0.15) : spring
    }
}
