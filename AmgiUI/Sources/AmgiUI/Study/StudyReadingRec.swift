public import SwiftUI
import AmgiTheme

/// A book recommendation tile in the Study "Reading recommendations" strip.
/// 120×170 rounded rectangle with title (serif caption) and author
/// (uppercased micro) overlaid on a cover image or accentSoft placeholder.
public struct StudyReadingRec: View {
    public let data: StudyReadingRecData
    public let onTap: () -> Void

    @Environment(\.palette) private var palette

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
        .buttonStyle(.plain)
    }

    // MARK: - Tile

    private var tile: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tileFill)
            .frame(width: cardWidth, height: cardHeight)
            .overlay(coverImage)
            .overlay(textOverlay, alignment: .bottomLeading)
    }

    @ViewBuilder
    private var tileFill: some ShapeStyle {
        palette.accentSoft
    }

    @ViewBuilder
    private var coverImage: some View {
        if let path = data.coverImagePath,
           let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private var textOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(data.title)
                .amgiFont(.serifTitle)
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
