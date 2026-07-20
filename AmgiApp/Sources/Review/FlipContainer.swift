import SwiftUI

/// 3D flip for the review card surface (R12). The content builder receives
/// the *displayed* side, which swaps at the 90° seam — so the WebView path's
/// `isAnswerSide` reload happens during the back half of the animation, and
/// the native path swaps its parsed content the same way.
///
/// Reveal (`showBack` false→true) animates; reset (→false, on advance or
/// undo) snaps instantly so a new card never plays a stale reverse flip.
struct FlipContainer<Content: View>: View {
    let showBack: Bool
    @ViewBuilder let content: (_ isBack: Bool) -> Content

    @State private var displayedBack = false
    @State private var angle: Double = 0

    private static var halfDuration: Double { 0.175 }

    var body: some View {
        content(displayedBack)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
            .onChange(of: showBack) { _, newValue in
                if newValue {
                    flipToBack()
                } else {
                    displayedBack = false
                    angle = 0
                }
            }
    }

    private func flipToBack() {
        withAnimation(.easeIn(duration: Self.halfDuration)) { angle = 90 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.halfDuration))
            displayedBack = true
            angle = -90
            withAnimation(.easeOut(duration: Self.halfDuration)) { angle = 0 }
        }
    }
}
