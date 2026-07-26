import AmgiUI
import SwiftUI

struct BookCoverView: View {
    let coverArt: CoverArtSource
    let title: String
    let surname: String?
    let seed: String

    var body: some View {
        switch coverArt {
        case .epub(let url):
            ReaderCoverImage(fileURL: url, isEPUB: true) {
                BookCoverPlaceholder(title: title, surname: surname, seed: seed)
            }
        case .anki(let path):
            ReaderCoverImage(path: path) {
                BookCoverPlaceholder(title: title, surname: surname, seed: seed)
            }
        case .none:
            BookCoverPlaceholder(title: title, surname: surname, seed: seed)
        }
    }
}

#Preview("Placeholder fallback") {
    BookCoverView(
        coverArt: .none,
        title: "어린 왕자",
        surname: "Saint-Exupéry",
        seed: "book-id-001"
    )
    .frame(width: 140, height: 190)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .padding()
}
