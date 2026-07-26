public import SwiftUI
import AmgiTheme

/// Single subdeck row inside `DeckSubdecksCard`. Renders the deck's
/// glyph chip, leaf name, count badges, and a trailing chevron.
/// Tap is routed through the caller-supplied closure — Container layer
/// wires this to a programmatic navigation push so AmgiUI stays
/// independent of `NavigationLink(value:)` and AnkiKit's `DeckInfo`.
public struct DeckSubdeckRow: View {
    public let data: DeckSubdeckRowData
    public let showsDivider: Bool
    public let onTap: () -> Void

    @Environment(\.palette) private var palette

    public init(
        data: DeckSubdeckRowData,
        showsDivider: Bool,
        onTap: @escaping () -> Void
    ) {
        self.data = data
        self.showsDivider = showsDivider
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.textPrimary.opacity(0.05))
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(width: 30, height: 30)

                Text(data.name)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                Spacer()

                DeckCountBadges(
                    newCount: data.newCount,
                    learnCount: data.learnCount,
                    reviewCount: data.reviewCount
                )

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
#Preview("Subdeck row") {
    DeckSubdeckRow(
        data: DeckSubdeckRowData(
            id: 1,
            name: "Vocab Typing",
            fullName: "한국어::Vocab Typing",
            newCount: 20,
            learnCount: 0,
            reviewCount: 5,
            isFiltered: false
        ),
        showsDivider: true,
        onTap: {}
    )
    .padding()
    .environment(\.palette, .vividLight)
}

#Preview("Subdeck row — filtered, no new") {
    DeckSubdeckRow(
        data: DeckSubdeckRowData(
            id: 2,
            name: "Cloze Grammar",
            fullName: "한국어::Cloze Grammar",
            newCount: 0,
            learnCount: 4,
            reviewCount: 9,
            isFiltered: true
        ),
        showsDivider: false,
        onTap: {}
    )
    .padding()
    .environment(\.palette, .vividLight)
}
#endif
