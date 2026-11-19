//
//  WatchDeckDetailView.swift
//  WatchFeature
//
//  Created by Leaf Eriksen on 17.07.2026.
//

import AnkiClients
import AnkiKit
import Dependencies
import SwiftUI
import Theme

struct WatchDeckDetailView: View {
    let deck: DeckInfo
    @Dependency(\.deckClient) var deckClient
    @State private var counts: DeckCounts = .zero
    @Environment(\.palette) private var palette
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Compact Counts
                HStack {
                    countItem(label: String(localized: "New", bundle: .module), count: counts.newCount, color: palette.cardStateNew)
                    Spacer()
                    countItem(label: String(localized: "Learn", bundle: .module), count: counts.learnCount, color: palette.cardStateLearning)
                    Spacer()
                    countItem(label: String(localized: "Due", bundle: .module), count: counts.reviewCount, color: palette.cardStateReview)
                }
                .padding(.horizontal)
                NavigationLink {
                    WatchReviewView(
                        deckId: deck.id,
                        onFinish: { Task { await loadCounts() } }
                    )
                } label: {
                    Label(String(localized: "Study", bundle: .module), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Text("Tap to replay audio.", bundle: .module)
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
            counts = try await deckClient.countsForDeck(deck.id)
        } catch {
            counts = .zero
        }
    }
}
