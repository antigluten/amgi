public import SwiftUI
import AmgiTheme

/// Full-width "▶ Study Now" pill. Disabled state dims to 40% and drops
/// the accent shadow. No spinner — Container manages any pending state
/// externally if needed.
public struct DeckStudyButton: View {
    public let isDisabled: Bool
    public let disabledHint: String
    public let onTap: () -> Void

    @Environment(\.palette) private var palette

    public init(
        isDisabled: Bool,
        disabledHint: String = "Deck has no cards due",
        onTap: @escaping () -> Void
    ) {
        self.isDisabled = isDisabled
        self.disabledHint = disabledHint
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.callout.weight(.semibold))
                Text("Study Now")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(palette.accent, in: RoundedRectangle(cornerRadius: AmgiRadius.control, style: .continuous))
            .opacity(isDisabled ? 0.4 : 1.0)
            .shadow(color: isDisabled ? .clear : palette.accent.opacity(0.28), radius: 8, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel("Study now")
        .accessibilityHint(isDisabled ? disabledHint : "Start a review session")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Study button — enabled") {
    DeckStudyButton(isDisabled: false, onTap: {})
        .padding()
        .environment(\.palette, .vividLight)
}

#Preview("Study button — disabled") {
    DeckStudyButton(isDisabled: true, onTap: {})
        .padding()
        .environment(\.palette, .vividLight)
}
#endif
