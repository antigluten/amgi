import SwiftUI
import AmgiTheme

/// Top-of-screen "Importing…" pill shown while an .apkg / .colpkg import
/// is running. Hidden when `visible == false`.
struct ImportInProgressBanner: View {
    let visible: Bool

    var body: some View {
        if visible {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Importing…").amgiFont(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Bottom-of-screen toast surfaced after a successful filtered-deck rebuild.
/// `feedback == nil` hides the banner; the container animates the change.
struct RebuildFeedbackBanner: View {
    let feedback: String?

    @Environment(\.palette) private var palette

    var body: some View {
        if let feedback {
            Text(feedback)
                .amgiFont(.bodyEmphasis)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(palette.accent, in: Capsule())
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
        }
    }
}
