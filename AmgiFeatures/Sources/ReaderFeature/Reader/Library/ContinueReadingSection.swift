//
//  ContinueReadingSection.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 17.05.2026.
//

import Reader
import Theme
import SwiftUI

struct ContinueReadingSection: View {
    let items: [ContinueReadingItem]
    let bookForId: (String) -> ReaderBook?
    let progress: ReaderProgressCoordinator

    @Environment(\.palette) private var palette
    /// See `AllBooksSection` — the detail push grows from the tapped card.
    @Namespace private var coverTransition

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader
                ScrollView(.horizontal, showsIndicators: false) {
                    // Lazy: an eager HStack builds — and decodes the cover for
                    // — every book in the row before any of it is on screen.
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(items) { item in
                            if let book = bookForId(item.id) {
                                NavigationLink {
                                    ReaderBookDetailView(book: book, progress: progress)
                                        .navigationTransition(.zoom(sourceID: item.id, in: coverTransition))
                                } label: {
                                    ContinueReadingCard(item: item)
                                }
                                .buttonStyle(.pressScale)
                                .matchedTransitionSource(id: item.id, in: coverTransition)
                            } else {
                                ContinueReadingCard(item: item)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var sectionHeader: some View {
        Text("CONTINUE READING")
            .amgiFont(.captionBold)
            .tracking(1.4)
            .foregroundStyle(palette.textSecondary)
            .padding(.horizontal, 16)
    }
}
