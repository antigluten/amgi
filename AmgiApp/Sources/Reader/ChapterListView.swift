import AmgiReader
import AmgiTheme
import SwiftUI

struct ChapterListView: View {
    let book: ReaderBook
    let progress: ReaderProgressCoordinator

    @State private var savedProgress: ReaderSavedProgress?

    var body: some View {
        List(book.chapters) { chapter in
            NavigationLink {
                ChapterReaderView(book: book, chapter: chapter, progress: progress)
            } label: {
                ChapterRow(
                    chapter: chapter,
                    savedProgress: savedProgress?.chapterID == chapter.id ? savedProgress : nil
                )
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { savedProgress = await progress.resolved(bookID: book.id) }
        .toolbar {
            if let savedProgress, let chapter = book.chapters.first(where: { $0.id == savedProgress.chapterID }) {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ChapterReaderView(book: book, chapter: chapter, progress: progress)
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                }
            }
        }
    }
}

private struct ChapterRow: View {
    let chapter: ReaderChapter
    let savedProgress: ReaderSavedProgress?

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(chapter.title).amgiFont(.body)
            if let order = chapter.order {
                Text("Chapter \(order)").amgiFont(.caption).foregroundStyle(palette.textSecondary)
            }
            if let savedProgress {
                ProgressView(value: savedProgress.progress)
                    .tint(palette.accent)
                    .padding(.top, 2)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChapterListView(book: .sample, progress: ReaderProgressCoordinator())
    }
}
