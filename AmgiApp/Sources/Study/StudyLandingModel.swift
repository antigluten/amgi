import AmgiReader
import AmgiUI
import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Data loading for the study landing screen. Owns the deck + reader-book
/// clients, the progress coordinator, the mapped `StudyLandingContent.State`,
/// and the book-sheet selection so the Container carries no `@Dependency`;
/// the Container keeps only its navigation callback and load-task lifecycle.
@Observable
@MainActor
final class StudyLandingModel {
    var contentState: StudyLandingContent.State = .loading
    var selectedBook: ReaderBook?

    let progressCoordinator = ReaderProgressCoordinator()

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient
    @ObservationIgnored @Dependency(\.readerBookClient) private var readerBookClient

    func load() async {
        do {
            // 1. Deck tree → flatten → filter due > 0 → sort desc
            let tree = try await deckClient.fetchTree()
            guard !tree.isEmpty else {
                contentState = .empty
                return
            }

            let allDecks: [DeckInfo] = tree.flattened()
            let dueDecks = allDecks
                .filter { $0.counts.total > 0 }
                .sorted { $0.counts.total > $1.counts.total }

            let deckRows = dueDecks.map { deck in
                StudyDeckRowData(
                    id: deck.id.rawValue,
                    name: deck.name,
                    totalDue: deck.counts.total,
                    newCount: deck.counts.newCount,
                    learnCount: deck.counts.learnCount,
                    reviewCount: deck.counts.reviewCount,
                    isFiltered: deck.isFiltered
                )
            }

            // 2. Total counts for the summary ring (sum of all decks, not just due)
            let totalDue = allDecks.reduce(0) { $0 + $1.counts.total }
            let totalNew = allDecks.reduce(0) { $0 + $1.counts.newCount }
            let totalLearn = allDecks.reduce(0) { $0 + $1.counts.learnCount }
            let totalReview = allDecks.reduce(0) { $0 + $1.counts.reviewCount }
            let deckCount = dueDecks.count

            // 3. Build subtitle label from current weekday + deck count
            let weekday = Date().formatted(.dateTime.weekday(.wide))
            let subtitleLabel: String
            if deckCount == 0 {
                subtitleLabel = weekday
            } else {
                subtitleLabel = "\(weekday) · \(deckCount) deck\(deckCount == 1 ? "" : "s") due"
            }

            let summary = StudySummaryData(
                totalDue: totalDue,
                newCount: totalNew,
                learnCount: totalLearn,
                reviewCount: totalReview,
                todayLabel: "Today",
                subtitleLabel: subtitleLabel,
                deckCount: deckCount
            )

            // 4. Books → sort by lastRead desc → take 8 → map to DTO
            let readingRecs = await loadReadingRecs()

            contentState = .loaded(summary: summary, decks: deckRows, readingRecs: readingRecs)
        } catch {
            print("[StudyLandingModel] Error loading: \(error)")
            contentState = .empty
        }
    }

    func selectBook(_ bookID: String) {
        guard let configuration = ReaderConfigurationLoader.loadConfiguration() else { return }
        Task {
            if let book = try? await readerBookClient.loadBook(bookID, configuration) {
                selectedBook = book
            }
        }
    }

    private func loadReadingRecs() async -> [StudyReadingRecData] {
        guard let configuration = ReaderConfigurationLoader.loadConfiguration(),
              let books = try? await readerBookClient.loadBooks(configuration) else {
            return []
        }

        return books
            .sorted { lhs, rhs in
                let lDate = progressCoordinator.resolved(bookID: lhs.id)?.updatedAt ?? .distantPast
                let rDate = progressCoordinator.resolved(bookID: rhs.id)?.updatedAt ?? .distantPast
                return lDate > rDate
            }
            .prefix(8)
            .map { book in
                StudyReadingRecData(
                    id: book.id,
                    title: book.title,
                    coverImagePath: book.coverImagePath,
                    authorLabel: ""
                )
            }
    }
}
