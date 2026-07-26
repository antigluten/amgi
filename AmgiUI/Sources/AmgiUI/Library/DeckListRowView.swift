public import SwiftUI
import AmgiTheme

/// Single Library deck row: tile + name + meta line + count badges or
/// "Up to date" checkmark. Subdecks are not nested in the list — the
/// meta line surfaces the subdeck count textually.
public struct DeckListRowView: View {
    let data: DeckRowViewData
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void

    @State private var showDeleteAlert = false
    @Environment(\.palette) private var palette

    public init(
        data: DeckRowViewData,
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRename: @escaping () -> Void
    ) {
        self.data = data
        self.onTap = onTap
        self.onDelete = onDelete
        self.onRename = onRename
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                DeckTile(name: data.name, isFiltered: data.isFiltered)
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.name)
                        .amgiFont(.body)
                        .bold()
                        .foregroundStyle(palette.textPrimary)
                    Text(metaLine)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                trailingContent
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { showDeleteAlert = true } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { onRename() } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .alert("Delete \"\(data.name)\"?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the deck and all its cards.")
        }
    }

    private var metaLine: String {
        switch (data.totalCount, data.subdeckCount) {
        case (0, _):           return "Up to date"
        case (let n, 0):       return "\(n) due"
        case (let n, let s):   return "\(n) due · \(s) subdeck\(s == 1 ? "" : "s")"
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        if data.totalCount == 0 {
            Image(systemName: "checkmark")
                .foregroundStyle(palette.textTertiary)
        } else {
            DeckCountBadges(
                newCount: data.newCount,
                learnCount: data.learnCount,
                reviewCount: data.reviewCount
            )
        }
    }
}

// MARK: - DeckTile

private struct DeckTile: View {
    let name: String
    let isFiltered: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        let resolved = DeckTileGlyph.resolve(deckName: name, palette: palette)
        let fill: Color
        let glyphColor: Color
        switch resolved.mode {
        case .emoji:
            fill = palette.surfaceElevated
            glyphColor = palette.textPrimary
        case .letter(let tint):
            fill = tint
            glyphColor = .white
        }

        return ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fill)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(resolved.display)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(glyphColor)
                )
            if isFiltered {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(palette.customStudyBadge, in: Circle())
                    .offset(x: 4, y: 4)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Due cards row") {
    DeckListRowView(
        data: DeckRowViewData(
            id: 1,
            name: "한국어",
            fullName: "한국어",
            newCount: 20,
            learnCount: 93,
            reviewCount: 74,
            isFiltered: false,
            subdeckCount: 4
        ),
        onTap: {}, onDelete: {}, onRename: {}
    )
    .padding()
    .environment(\.palette, .vividLight)
}

#Preview("Up to date row") {
    DeckListRowView(
        data: DeckRowViewData(
            id: 2,
            name: "Español",
            fullName: "Español",
            newCount: 0,
            learnCount: 0,
            reviewCount: 0,
            isFiltered: false,
            subdeckCount: 0
        ),
        onTap: {}, onDelete: {}, onRename: {}
    )
    .padding()
    .environment(\.palette, .vividLight)
}

#Preview("Filtered deck row") {
    DeckListRowView(
        data: DeckRowViewData(
            id: 3,
            name: "Hardest cards",
            fullName: "Hardest cards",
            newCount: 0,
            learnCount: 0,
            reviewCount: 24,
            isFiltered: true,
            subdeckCount: 0
        ),
        onTap: {}, onDelete: {}, onRename: {}
    )
    .padding()
    .environment(\.palette, .vividLight)
}
#endif
