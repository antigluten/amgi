public import SwiftUI
import AmgiTheme

/// Inset-group CUSTOM STUDY card for filtered decks: Rebuild + Empty
/// action rows. Mirrors `design/deck.jsx` action-row treatment — icon
/// chip in the tone color, label same tone, leading divider inset.
public struct DeckCustomStudyCard: View {
    public let isActionInFlight: Bool
    public let onRebuild: () -> Void
    public let onEmpty: () -> Void

    @Environment(\.palette) private var palette

    public init(
        isActionInFlight: Bool,
        onRebuild: @escaping () -> Void,
        onEmpty: @escaping () -> Void
    ) {
        self.isActionInFlight = isActionInFlight
        self.onRebuild = onRebuild
        self.onEmpty = onEmpty
    }

    public var body: some View {
        VStack(spacing: 0) {
            DeckCustomStudyActionRow(
                icon: "arrow.clockwise",
                label: "Rebuild",
                tone: palette.accent,
                showsDivider: true,
                isDisabled: isActionInFlight,
                onTap: onRebuild
            )
            DeckCustomStudyActionRow(
                icon: "tray",
                label: "Empty",
                tone: palette.danger,
                showsDivider: false,
                isDisabled: isActionInFlight,
                onTap: onEmpty
            )
        }
        .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: AmgiRadius.inset, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AmgiRadius.inset, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 0.5)
        )
    }
}

/// Public so future variants (e.g. Reset, Reschedule) can compose
/// additional rows without duplicating the chip+label treatment.
public struct DeckCustomStudyActionRow: View {
    public let icon: String
    public let label: String
    public let tone: Color
    public let showsDivider: Bool
    public let isDisabled: Bool
    public let onTap: () -> Void

    @Environment(\.palette) private var palette

    public init(
        icon: String,
        label: String,
        tone: Color,
        showsDivider: Bool,
        isDisabled: Bool,
        onTap: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.tone = tone
        self.showsDivider = showsDivider
        self.isDisabled = isDisabled
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tone.opacity(0.14))
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tone)
                }
                .frame(width: 30, height: 30)
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tone)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(palette.border)
                    .frame(height: 0.5)
                    .padding(.leading, 56)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Custom study — idle") {
    DeckCustomStudyCard(isActionInFlight: false, onRebuild: {}, onEmpty: {})
        .padding()
        .environment(\.palette, .vividLight)
}

#Preview("Custom study — in flight") {
    DeckCustomStudyCard(isActionInFlight: true, onRebuild: {}, onEmpty: {})
        .padding()
        .environment(\.palette, .vividLight)
}
#endif
