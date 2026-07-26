#if DEBUG
import Foundation

// Sample reader data for SwiftUI `#Preview` blocks. Deterministic so preview
// snapshots stay stable, and gated by DEBUG so release builds skip them.

extension ReaderChapter {
    public static let sample = ReaderChapter(
        id: 1,
        bookID: "sample-book",
        bookTitle: "The Little Prince",
        title: "Chapter 1",
        order: "1",
        content: """
        <p>Once when I was six years old I saw a magnificent picture in a book, \
        called <em>True Stories from Nature</em>, about the primeval forest. It \
        was a picture of a boa constrictor in the act of swallowing an animal.</p>
        <p>In the book it said: &ldquo;Boa constrictors swallow their prey whole, \
        without chewing it. After that they are not able to move, and they sleep \
        through the six months that they need for digestion.&rdquo;</p>
        """,
        language: "en"
    )

    public static let sampleList: [ReaderChapter] = (1...8).map { i in
        ReaderChapter(
            id: Int64(i),
            bookID: "sample-book",
            bookTitle: "The Little Prince",
            title: "Chapter \(i)",
            order: "\(i)",
            content: "<p>The text of chapter \(i) goes here…</p>",
            language: "en"
        )
    }
}

extension ReaderBook {
    public static let sample = ReaderBook(
        id: "sample-book",
        title: "The Little Prince",
        author: "Antoine de Saint-Exupéry",
        language: "en",
        chapters: ReaderChapter.sampleList,
        pageCount: 96
    )
}
#endif
