//
//  ReaderCoverImage.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 05.05.2026.
//

import Theme
import UI
import AnkiClients
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
    @Environment(\.colorScheme) private var colorScheme

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
                    .amgiFont(size: 9, weight: .heavy, relativeTo: .caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .amgiMaterial(.light, in: Capsule())
                    .foregroundStyle(palette.textPrimary)
                    .padding(4)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch resolved {
        case .none:
            placeholder()
        case .remote(let url):
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                        .overlay { Rectangle().stroke(imageOutlineColor, lineWidth: 1) }
                default:
                    placeholder()
                }
            }
        case .local(let url):
            // Downsampled off the main thread: covers are drawn at ~120pt but
            // the source files are frequently thousands of pixels wide.
            DownsampledImage(url: url, maxPixelSize: AmgiImagePixelSize.cover) { image in
                image.resizable().scaledToFill()
                    .overlay { Rectangle().stroke(imageOutlineColor, lineWidth: 1) }
            } placeholder: {
                placeholder()
            }
        }
    }

    /// Resolution runs a regex and hits the filesystem, so it's memoized —
    /// `body` re-runs often while the library grid scrolls.
    private var resolved: ResolvedCover {
        switch source {
        case .fileURL(let url):
            return url.map { .local($0) } ?? .none
        case .ankiMediaPath(let path):
            return CoverURLCache.shared.resolve(path)
        }
    }

    private var imageOutlineColor: Color {
        colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.1)
    }

}

/// Where a cover ended up resolving to, if anywhere.
enum ResolvedCover {
    case none
    /// A URL with a scheme — fetched through `AsyncImage`.
    case remote(URL)
    /// A file on disk — decoded and downsampled locally.
    case local(URL)
}

/// Memoizes cover-field resolution. Each miss runs a regex and a filesystem
/// stat, and the same field is re-resolved on every `body` pass of every cell
/// in the library grid, so the cache is what keeps that off the scroll path.
@MainActor
final class CoverURLCache {
    static let shared = CoverURLCache()

    private var entries: [String: ResolvedCover] = [:]

    func resolve(_ raw: String?) -> ResolvedCover {
        guard let raw, !raw.isEmpty else { return .none }
        if let hit = entries[raw] { return hit }
        let result = Self.resolveUncached(raw)
        entries[raw] = result
        return result
    }

    private static func resolveUncached(_ raw: String) -> ResolvedCover {
        // Case 1: already a real URL.
        if let url = URL(string: raw), url.scheme != nil {
            return url.isFileURL ? .local(url) : .remote(url)
        }

        // Case 2: HTML fragment with an <img src="…">.
        let filename = extractImgSrc(from: raw) ?? raw

        // Case 3: bare filename — resolve against Anki media folder.
        // `localURL` already joins against the media folder and stats the
        // result, so the percent-decode is all this adds.
        @Dependency(\.mediaClient) var mediaClient
        guard let url = mediaClient.localURL(filename.removingPercentEncoding ?? filename) else {
            return .none
        }
        return .local(url)
    }

    /// Pulls the first `src="…"` (or `src='…'`) value from an HTML
    /// fragment. Anki cover fields are typically a single `<img>`, so we
    /// don't need a real HTML parser here.
    private static func extractImgSrc(from html: String) -> String? {
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

#if DEBUG

#Preview {
    // The unresolved (placeholder) case — needs no media folder or backend.
    HStack(spacing: 16) {
        ReaderCoverImage(fileURL: nil) { CoverPlaceholder() }
        ReaderCoverImage(path: nil, isEPUB: true) { CoverPlaceholder() }
    }
    .frame(height: 180)
    .padding()
}
#endif
