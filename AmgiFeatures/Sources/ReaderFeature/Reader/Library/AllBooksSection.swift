//
//  AllBooksSection.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 17.05.2026.
//

import Reader
import Theme
import SwiftUI

struct AllBooksSection: View {
    let items: [BookCellItem]
    let bookForId: (String) -> ReaderBook?
    let progress: ReaderProgressCoordinator

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14, alignment: .top),
        count: 3
    )

    @Environment(\.palette) private var palette
    /// Anchors each book's detail push to the cover the user tapped, so the
    /// screen grows out of that cover instead of cutting in from the edge.
    @Namespace private var coverTransition

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ALL BOOKS")
                .amgiFont(.captionBold)
                .tracking(1.4)
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(items) { item in
                    if let book = bookForId(item.id) {
                        NavigationLink {
                            ReaderBookDetailView(book: book, progress: progress)
                                .navigationTransition(.zoom(sourceID: item.id, in: coverTransition))
                        } label: {
                            AllBooksCell(item: item)
                        }
                        .buttonStyle(.pressScale)
                        .matchedTransitionSource(id: item.id, in: coverTransition)
                    } else {
                        AllBooksCell(item: item)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
