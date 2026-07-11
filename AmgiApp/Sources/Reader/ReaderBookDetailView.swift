import AmgiReader
import Foundation
import SwiftUI

struct ReaderBookDetailView: View {
    let book: ReaderBook
    let progress: ReaderProgressCoordinator

    @State private var model = ReaderBookDetailModel()
    @State private var savedProgress: ReaderSavedProgress?

    var body: some View {
        ReaderBookDetailContent(
            book: book,
            savedProgress: savedProgress,
            state: model.state,
            progress: progress
        )
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            savedProgress = await progress.resolved(bookID: book.id)
            await model.load(book: book)
        }
        .onReceive(NotificationCenter.default.publisher(for: .amgiReaderCardAdded)) { note in
            guard let bookID = note.userInfo?["bookID"] as? String,
                  bookID == book.id else { return }
            Task { await model.load(book: book) }
        }
    }
}

private struct ReaderBookDetailContent: View {
    let book: ReaderBook
    let savedProgress: ReaderSavedProgress?
    let state: ReaderBookDetailModel.ViewState
    let progress: ReaderProgressCoordinator

    private var coverURL: URL? {
        if case .loaded(let url, _, _) = state { return url }
        return nil
    }

    private var cardsByChapter: [Int64: Int] {
        if case .loaded(_, let counts, _) = state { return counts }
        return [:]
    }

    private var pageRanges: [Int64: ClosedRange<Int>] {
        if case .loaded(_, _, let ranges) = state { return ranges }
        return [:]
    }

    private var isEPUB: Bool {
        if case .epub = book.source { return true }
        return false
    }

    private var overallProgressPercent: Int {
        let total = book.chapters.count
        guard total > 0 else { return 0 }
        guard let saved = savedProgress,
              let savedIndex = book.chapters.firstIndex(where: { $0.id == saved.chapterID }) else {
            return 0
        }
        let completed = Double(savedIndex)
        let combined = (completed + saved.progress) / Double(total)
        return Int((combined * 100).rounded())
    }

    private var currentChapterIndex: Int? {
        guard let saved = savedProgress else { return nil }
        return book.chapters.firstIndex(where: { $0.id == saved.chapterID })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BookHeaderView(
                    book: book,
                    coverURL: coverURL,
                    isEPUB: isEPUB
                )
                ContinueBlock(
                    percent: overallProgressPercent,
                    resumeIndex: resumeChapterIndex,
                    destination: destinationForChapter(at:)
                )
                ChaptersSection(
                    book: book,
                    pageRanges: pageRanges,
                    cardsByChapter: cardsByChapter,
                    currentIndex: currentChapterIndex,
                    isChapterComplete: isChapterComplete(at:),
                    destination: destinationForChapter(at:)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    /// The chapter we resume into when the user taps "Continue". Defaults
    /// to the first chapter on a brand-new book; otherwise picks the
    /// last-read chapter index, falling back to 0 if the saved chapterID
    /// can't be matched (book mutated since last read, for example).
    private var resumeChapterIndex: Int {
        if let saved = savedProgress,
           let index = book.chapters.firstIndex(where: { $0.id == saved.chapterID }) {
            return index
        }
        return 0
    }
}

private extension ReaderBookDetailContent {
    @ViewBuilder
    func destinationForChapter(at index: Int) -> some View {
        if case .epub = book.source {
            EPUBChapterReaderView(
                book: book,
                chapterIndex: max(0, min(index, book.chapters.count - 1)),
                progressCoordinator: progress
            )
        } else if index >= 0, index < book.chapters.count {
            ChapterReaderView(
                book: book,
                chapter: book.chapters[index],
                progress: progress
            )
        }
    }

    func isChapterComplete(at index: Int) -> Bool {
        guard let saved = savedProgress,
              let savedIndex = book.chapters.firstIndex(where: { $0.id == saved.chapterID }) else {
            return false
        }
        if index < savedIndex { return true }
        if index == savedIndex { return saved.progress >= 0.99 }
        return false
    }
}

// MARK: - Header

private struct BookHeaderView: View {
    let book: ReaderBook
    let coverURL: URL?
    let isEPUB: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                cover
                    .frame(width: 140, height: 190)
                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                Spacer()
            }
            .padding(.top, 8)

            Text(book.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if let author = book.author {
                Text(author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            if let meta = metaText {
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var cover: some View {
        if isEPUB {
            ReaderCoverImage(fileURL: coverURL, isEPUB: true) { placeholder }
        } else {
            ReaderCoverImage(path: book.coverImagePath) { placeholder }
        }
    }

    private var placeholder: some View {
        Image(systemName: "book.closed")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var metaText: String? {
        var parts: [String] = []
        if let pages = book.pageCount {
            parts.append("\(pages) pages")
        }
        if let language = book.language, !language.isEmpty {
            parts.append(language)
        }
        let chapters = book.chapters.count
        parts.append("\(chapters) chapter\(chapters == 1 ? "" : "s")")
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Continue block

private struct ContinueBlock<Destination: View>: View {
    let percent: Int
    let resumeIndex: Int
    @ViewBuilder var destination: (Int) -> Destination

    var body: some View {
        VStack(spacing: 8) {
            NavigationLink {
                destination(resumeIndex)
            } label: {
                Text("Continue · \(percent)%")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            ProgressView(value: Double(percent), total: 100)
                .progressViewStyle(.linear)
                .tint(Color.accentColor)
        }
    }
}

// MARK: - Chapters section

private struct ChaptersSection<Destination: View>: View {
    let book: ReaderBook
    let pageRanges: [Int64: ClosedRange<Int>]
    let cardsByChapter: [Int64: Int]
    let currentIndex: Int?
    let isChapterComplete: (Int) -> Bool
    @ViewBuilder var destination: (Int) -> Destination

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHAPTERS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            VStack(spacing: 0) {
                ForEach(Array(book.chapters.enumerated()), id: \.element.id) { index, chapter in
                    NavigationLink {
                        destination(index)
                    } label: {
                        ChapterRow(
                            index: index,
                            chapter: chapter,
                            pageRange: pageRanges[chapter.id],
                            cardsAdded: cardsByChapter[chapter.id] ?? 0,
                            isComplete: isChapterComplete(index),
                            isCurrent: currentIndex == index
                        )
                    }
                    .buttonStyle(.plain)
                    if index < book.chapters.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct ChapterRow: View {
    let index: Int
    let chapter: ReaderChapter
    let pageRange: ClosedRange<Int>?
    let cardsAdded: Int
    let isComplete: Bool
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            leading
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title)
                    .font(.body)
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                    .lineLimit(2)
                if let subline {
                    Text(subline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leading: some View {
        if isComplete {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        } else {
            Text(String(format: "%02d", index + 1))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
        }
    }

    private var subline: String? {
        var parts: [String] = []
        if let range = pageRange {
            parts.append(range.lowerBound == range.upperBound
                ? "\(range.lowerBound)"
                : "\(range.lowerBound)–\(range.upperBound)")
        }
        if cardsAdded > 0 {
            parts.append("\(cardsAdded) card\(cardsAdded == 1 ? "" : "s") added")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
