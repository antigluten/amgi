import AmgiTheme
import SwiftUI

struct AllBooksCell: View {
    let item: BookCellItem

    private static let coverAspect: CGFloat = 100.0 / 136.0

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookCoverView(
                coverArt: item.coverArt,
                title: item.title,
                surname: item.surname,
                seed: item.id
            )
            .aspectRatio(Self.coverAspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.title)
                .amgiFont(.bodyEmphasis)
                .lineLimit(2)
                .foregroundStyle(palette.textPrimary)

            if let author = item.author {
                Text(author)
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    AllBooksCell(
        item: BookCellItem(
            id: "preview-2",
            title: "Don Quijote",
            author: "Miguel de Cervantes",
            surname: "Cervantes",
            coverArt: .none
        )
    )
    .frame(width: 110)
    .padding()
}
