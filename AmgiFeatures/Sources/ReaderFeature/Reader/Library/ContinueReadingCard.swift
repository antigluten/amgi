//
//  ContinueReadingCard.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 17.05.2026.
//

import Theme
import UI
import SwiftUI

struct ContinueReadingCard: View {
    let item: ContinueReadingItem

    private static let coverWidth: CGFloat = 220
    private static let coverAspect: CGFloat = 100.0 / 136.0

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
            Text(item.title)
                .amgiFont(.cardTitle)
                .lineLimit(2)
                .foregroundStyle(palette.textPrimary)
            Text(subtitle)
                .amgiFont(.body)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
            ProgressView(value: item.progress)
                .progressViewStyle(.linear)
                .tint(palette.accent)
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
        .clipShape(RoundedRectangle(cornerRadius: AmgiRadius.control))
        .overlay(alignment: .topTrailing) {
            RibbonShape()
                .fill(BookCoverPalette.resolve(seed: item.id).lineColor)
                .frame(width: 16, height: 28)
                .padding(.trailing, 16)
        }
    }

    private struct RibbonShape: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.4))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }

    private var subtitle: String {
        let pct = Int((item.progress * 100).rounded())
        let when = BookMetaFormatters.relativeReadingDate(item.updatedAt)
        return "\(pct)% · \(when)"
    }
}

#if DEBUG

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
#endif
