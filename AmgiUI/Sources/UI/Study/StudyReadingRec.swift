//
//  StudyReadingRec.swift
//  UI
//
//  Created by Vladimir Gusev on 15.05.2026.
//

public import SwiftUI
import Theme

/// A book recommendation tile in the Study "Reading recommendations" strip.
/// 120×170 rounded rectangle with title (serif caption) and author
/// (uppercased micro) overlaid on a cover image or accentSoft placeholder.
public struct StudyReadingRec: View {
    public let data: StudyReadingRecData
    public let onTap: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    private let cardWidth: CGFloat = 120
    private let cardHeight: CGFloat = 170
    private let cornerRadius: CGFloat = 10

    public init(data: StudyReadingRecData, onTap: @escaping () -> Void) {
        self.data = data
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            tile
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressScale)
    }

    // MARK: - Tile

    private var tile: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tileFill)
            .frame(width: cardWidth, height: cardHeight)
            .overlay { coverImage }
            .overlay(alignment: .bottomLeading) { textOverlay }
    }

    @ViewBuilder
    private var tileFill: some ShapeStyle {
        palette.accentSoft
    }

    @ViewBuilder
    private var coverImage: some View {
        // Downsampled off the main thread — the source cover is far larger
        // than the tile it's drawn into.
        DownsampledImage(
            url: data.coverImagePath.map { URL(fileURLWithPath: $0) },
            maxPixelSize: AmgiImagePixelSize.cover
        ) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.1), lineWidth: 1)
                )
        } placeholder: {
            EmptyView()
        }
    }

    private var textOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(data.title)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            if !data.authorLabel.isEmpty {
                Text(data.authorLabel.uppercased())
                    .amgiFont(.micro)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            }
        }
        .padding(10)
    }
}

// MARK: - Previews

#if DEBUG
private let sampleRec = StudyReadingRecData(
    id: "the-little-prince",
    title: "어린 왕자",
    coverImagePath: nil,
    authorLabel: "Antoine de Saint-Exupéry"
)

#Preview("Reading rec tile") {
    StudyReadingRec(data: sampleRec, onTap: {})
        .padding()
        .environment(\.palette, .vividLight)
}

#Preview("Norwegian Wood") {
    StudyReadingRec(
        data: StudyReadingRecData(
            id: "norwegian-wood",
            title: "Norwegian Wood",
            coverImagePath: nil,
            authorLabel: "Haruki Murakami"
        ),
        onTap: {}
    )
    .padding()
    .environment(\.palette, .vividLight)
}

#Preview("Dark") {
    StudyReadingRec(data: sampleRec, onTap: {})
        .padding()
        .background(Color.black)
        .environment(\.palette, .vividDark)
}
#endif
