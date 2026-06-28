import SwiftUI

struct AllBooksCell: View {
    let item: BookCellItem

    private static let coverAspect: CGFloat = 100.0 / 136.0

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
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            if let author = item.author {
                Text(author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
