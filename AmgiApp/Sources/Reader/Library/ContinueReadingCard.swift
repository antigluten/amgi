// AmgiApp/Sources/Reader/Library/ContinueReadingCard.swift
import AmgiUI
import SwiftUI

struct ContinueReadingCard: View {
    let item: ContinueReadingItem

    private static let coverWidth: CGFloat = 220
    private static let coverAspect: CGFloat = 100.0 / 136.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
            Text(item.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            ProgressView(value: item.progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
        }
        .frame(width: Self.coverWidth, alignment: .leading)
    }

    private var cover: some View {
        BookCoverView(
            coverArt: item.coverArt,
            title: item.title,
            surname: item.surname,
            seed: item.id
        )
        .aspectRatio(Self.coverAspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(10)
        }
    }

    private var subtitle: String {
        let pct = Int((item.progress * 100).rounded())
        let when = BookMetaFormatters.relativeReadingDate(item.updatedAt)
        return "\(pct)% · \(when)"
    }
}

#Preview {
    ContinueReadingCard(
        item: ContinueReadingItem(
            id: "preview-1",
            title: "어린 왕자",
            surname: "Saint-Exupéry",
            progress: 0.07,
            updatedAt: Date(),
            coverArt: .none
        )
    )
    .padding()
}
