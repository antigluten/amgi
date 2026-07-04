import AnkiClients
import AnkiKit
import Dependencies
import SwiftUI

struct WatchDeckDetailView: View {
    let deck: DeckInfo
    @Dependency(\.deckClient) var deckClient
    @State private var counts: DeckCounts = .zero
    @Environment(\.dismiss) private var dismiss
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
                NavigationLink {
                    WatchReviewView(
                        deckId: deck.id,
                        onDismiss: {
                            dismiss()
                            Task { await loadCounts() }
                        }
                    )
                } label: {
                    Label("Study", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(counts.total == 0)
                Text("Tap to replay audio, double tap to exit.")
            }
        }
        .navigationTitle(deck.name.split(separator: "::").last ?? "")
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
