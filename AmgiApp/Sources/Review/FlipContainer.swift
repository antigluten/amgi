import SwiftUI

/// Answer reveal for the native card surface (R12).
///
/// A 3D `rotation3DEffect` flip rasterizes SwiftUI text into an offscreen
/// texture and samples it at low effective resolution at steep angles, so the
/// answer settles in visibly blurred for ~200ms before snapping crisp. Instead
/// the two sides cross-dissolve with a small settle-in scale — vector-crisp
/// throughout, and still reads as a reveal.
///
/// Reveal (`showBack` false→true) animates; reset (→false, on advance or undo)
/// snaps instantly so a new card never plays a stale reverse animation.
///
/// Only the native path uses this; WebView cards swap sides directly, because a
/// live `WKWebView` rasterizes even worse under a transform.
struct FlipContainer<Content: View>: View {
    let showBack: Bool
    @ViewBuilder let content: (_ isBack: Bool) -> Content

    @State private var displayedBack = false

    var body: some View {
        content(displayedBack)
            .id(displayedBack)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .onChange(of: showBack) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.22)) { displayedBack = true }
                } else {
                    var snap = Transaction()
                    snap.disablesAnimations = true
                    withTransaction(snap) { displayedBack = false }
                }
            }
    }
}
