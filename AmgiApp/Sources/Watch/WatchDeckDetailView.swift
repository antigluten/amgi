import AnkiClients
import AnkiKit
import Dependencies
import SwiftUI

struct WatchDeckDetailView: View {
    let deck: DeckInfo
    @Dependency(\.deckClient) var deckClient
    @State private var counts: DeckCounts = .zero
    @State private var showReview = false
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Compact Counts
                HStack {
                    countItem(label: "New", count: counts.newCount, color: .blue)
                    Spacer()
                    countItem(label: "Learn", count: counts.learnCount, color: .orange)
                    Spacer()
                    countItem(label: "Due", count: counts.reviewCount, color: .green)
                }
                .padding(.horizontal)
                Button {
                    showReview = true
                } label: {
                    Label("Study", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(counts.total == 0)
                Text("When you are done, double tap the screen to return here.")
            }
        }
        .navigationTitle(deck.name.split(separator: "::").last ?? "")
        .fullScreenCover(isPresented: $showReview) {
            WatchReviewView(deckId: deck.id) {
                showReview = false
                Task { await loadCounts() }
            }
        }
        .task {
            await loadCounts()
        }
    }
    private func countItem(label: String, count: Int, color: Color) -> some View {
        VStack {
            Text("\(count)")
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    private func loadCounts() async {
        do {
            counts = try deckClient.countsForDeck(deck.id)
        } catch {
            counts = .zero
        }
    }
}
