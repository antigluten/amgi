import AmgiTheme
import SwiftUI

// This file provides compatibility modifiers and extensions for shared views
// (like Stats) that depend on amgi-prefixed styling, without requiring
// platform-specific duplicates of the entire theme system.

extension View {
    /// Provides the card styling expected by shared Stats views.
    func amgiCard(elevated: Bool = false) -> some View {
        self.padding(AmgiSpacing.md)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}
