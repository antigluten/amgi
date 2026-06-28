import AmgiReader
import SwiftUI

struct ChapterListView: View {
    let book: ReaderBook
    let progress: ReaderProgressCoordinator

    private var savedProgress: ReaderSavedProgress? { progress.resolved(bookID: book.id) }

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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(chapter.title).font(.body)
            if let order = chapter.order {
                Text("Chapter \(order)").font(.caption).foregroundStyle(.secondary)
            }
            if let savedProgress {
                ProgressView(value: savedProgress.progress)
                    .tint(.accentColor)
                    .padding(.top, 2)
            }
        }
    }
}
