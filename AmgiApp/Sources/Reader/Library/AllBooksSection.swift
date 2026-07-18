import AmgiReader
import AmgiTheme
import SwiftUI

struct AllBooksSection: View {
    let items: [BookCellItem]
    let bookForId: (String) -> ReaderBook?
    let progress: ReaderProgressCoordinator

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14, alignment: .top),
        count: 3
    )

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ALL BOOKS")
                .amgiFont(.captionBold)
                .tracking(1.4)
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(items) { item in
                    if let book = bookForId(item.id) {
                        NavigationLink {
                            ReaderBookDetailView(book: book, progress: progress)
                        } label: {
                            AllBooksCell(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        AllBooksCell(item: item)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
