import AmgiTheme
import AnkiBackend
import Dependencies
import Foundation
import SwiftUI

/// Renders a book cover from whatever shape the user's notetype stored in
/// the cover field. Three cases worth handling:
///
/// 1. A full URL with scheme (`https://…`, `file://…`) — pass through to
///    `AsyncImage`.
/// 2. An HTML fragment like `<img src="cover.jpg">` — extract the first
///    `src` and resolve against the Anki media folder.
/// 3. A bare filename like `cover.jpg` — resolve directly against the
///    Anki media folder.
///
/// When nothing resolves, fall through to `placeholder`.
struct ReaderCoverImage<Placeholder: View>: View {
    enum Source {
        case ankiMediaPath(String?)
        case fileURL(URL?)
    }

    let source: Source
    let isEPUB: Bool
    @ViewBuilder let placeholder: () -> Placeholder

    @Environment(\.palette) private var palette

    init(path: String?, isEPUB: Bool = false, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.source = .ankiMediaPath(path)
        self.isEPUB = isEPUB
        self.placeholder = placeholder
    }

    init(fileURL: URL?, isEPUB: Bool = false, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.source = .fileURL(fileURL)
        self.isEPUB = isEPUB
        self.placeholder = placeholder
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            if isEPUB {
                Text("EPUB")
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
                    .foregroundStyle(palette.textPrimary)
                    .padding(4)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch source {
        case .ankiMediaPath(let path):
            if let url = resolveCoverURL(path) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder()
                    }
                }
            } else {
                placeholder()
            }
        case .fileURL(let url):
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder()
            }
        }
    }

}

private extension ReaderCoverImage {
    func resolveCoverURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }

        // Case 1: already a real URL.
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }

        // Case 2: HTML fragment with an <img src="…">.
        let filename = extractImgSrc(from: raw) ?? raw

        // Case 3: bare filename — resolve against Anki media folder.
        @Dependency(\.ankiBackend) var backend
        guard let mediaPath = backend.currentMediaFolderPath else { return nil }
        let mediaRoot = URL(fileURLWithPath: mediaPath)
        let candidate = mediaRoot.appendingPathComponent(
            filename.removingPercentEncoding ?? filename,
            isDirectory: false
        )
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    /// Pulls the first `src="…"` (or `src='…'`) value from an HTML
    /// fragment. Anki cover fields are typically a single `<img>`, so we
    /// don't need a real HTML parser here.
    func extractImgSrc(from html: String) -> String? {
        guard html.contains("<img"), let match = html.range(
            of: #"src=["']([^"']+)["']"#,
            options: .regularExpression
        ) else { return nil }
        let segment = html[match]
        guard let valueStart = segment.firstIndex(where: { $0 == "\"" || $0 == "'" }) else {
            return nil
        }
        let openQuote = segment[valueStart]
        let afterOpen = segment.index(after: valueStart)
        guard let valueEnd = segment[afterOpen...].firstIndex(of: openQuote) else {
            return nil
        }
        return String(segment[afterOpen..<valueEnd])
    }
}

// MARK: - Preview

private struct CoverPlaceholder: View {
    @Environment(\.palette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: AmgiRadius.small)
            .fill(.gray.opacity(0.25))
            .overlay {
                Image(systemName: "book.closed")
                    .amgiFont(.displayHero)
                    .foregroundStyle(palette.textSecondary)
            }
            .frame(width: 120)
    }
}

#Preview {
    // The unresolved (placeholder) case — needs no media folder or backend.
    HStack(spacing: 16) {
        ReaderCoverImage(fileURL: nil) { CoverPlaceholder() }
        ReaderCoverImage(path: nil, isEPUB: true) { CoverPlaceholder() }
    }
    .frame(height: 180)
    .padding()
}
