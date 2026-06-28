public import SwiftUI
import AmgiTheme

/// Inset-group card listing the deck's direct children. Each row tap
/// fires `onSelect(rowData)` — the Container translates to a navigation
/// push. Empty `rows` should be filtered at the Container layer; if you
/// pass `[]` here the card still renders the section header but the
/// surface collapses to zero height.
public struct DeckSubdecksCard: View {
    public let rows: [DeckSubdeckRowData]
    public let onSelect: (DeckSubdeckRowData) -> Void

    @Environment(\.palette) private var palette

    public init(
        rows: [DeckSubdeckRowData],
        onSelect: @escaping (DeckSubdeckRowData) -> Void
    ) {
        self.rows = rows
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                DeckSubdeckRow(
                    data: row,
                    showsDivider: idx < rows.count - 1,
                    onTap: { onSelect(row) }
                )
            }
        }
        .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Previews

#if DEBUG
private let _subdecksSample: [DeckSubdeckRowData] = [
    DeckSubdeckRowData(id: 1, name: "Vocab Typing", fullName: "한국어::Vocab Typing", newCount: 20, learnCount: 0, reviewCount: 5, isFiltered: false),
    DeckSubdeckRowData(id: 2, name: "Cloze Grammar", fullName: "한국어::Cloze Grammar", newCount: 0, learnCount: 4, reviewCount: 9, isFiltered: false),
    DeckSubdeckRowData(id: 3, name: "Collocations", fullName: "한국어::Collocations", newCount: 0, learnCount: 14, reviewCount: 0, isFiltered: false),
    DeckSubdeckRowData(id: 4, name: "Manual Tags", fullName: "한국어::Manual Tags", newCount: 20, learnCount: 3, reviewCount: 3, isFiltered: false),
]

#Preview("Subdecks — four rows") {
    DeckSubdecksCard(rows: _subdecksSample, onSelect: { _ in })
        .padding()
        .environment(\.palette, .vividLight)
}

#Preview("Subdecks — single row") {
    DeckSubdecksCard(rows: [_subdecksSample[0]], onSelect: { _ in })
        .padding()
        .environment(\.palette, .vividLight)
}
#endif
