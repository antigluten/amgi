//
//  DownsampledImage.swift
//  UI
//
//  Created by Vladimir Gusev on 08.08.2026.
//

public import SwiftUI
import ImageIO

/// Target pixel budgets for on-disk images, sized to what they're actually
/// drawn at rather than whatever the source file happens to contain.
public enum AmgiImagePixelSize {
    /// Book covers — drawn at roughly 120–190pt, so 600px covers 3x displays.
    public static let cover: CGFloat = 600
    /// Card media — drawn up to full screen width, `scaledToFit`.
    public static let card: CGFloat = 1600
}

/// Loads images from disk downsampled to the size they'll be drawn at, off the
/// main thread, with an in-memory cache.
///
/// `UIImage(contentsOfFile:)` decodes at full resolution on whatever thread
/// calls it — a several-thousand-pixel cover costs a main-thread stall and a
/// large decoded buffer to draw a thumbnail. `CGImageSourceCreateThumbnailAtIndex`
/// decodes straight to the target size instead.
public enum DownsampledImageLoader {
    nonisolated(unsafe) private static let cache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.countLimit = 120
        return cache
    }()

    private static func key(_ url: URL, _ maxPixelSize: CGFloat) -> NSString {
        "\(url.path)#\(Int(maxPixelSize))" as NSString
    }

    /// Already-decoded image, if any — a cheap synchronous peek so a cell
    /// scrolling back into view doesn't flash its placeholder.
    public static func cached(url: URL, maxPixelSize: CGFloat) -> CGImage? {
        cache.object(forKey: key(url, maxPixelSize))
    }

    /// Decodes off the main thread, caches, and returns. `nil` if the file is
    /// missing or isn't a decodable image.
    public static func load(url: URL, maxPixelSize: CGFloat) async -> CGImage? {
        if let hit = cached(url: url, maxPixelSize: maxPixelSize) { return hit }
        let image = await Task.detached(priority: .userInitiated) {
            downsample(url: url, maxPixelSize: maxPixelSize)
        }.value
        if let image { cache.setObject(image, forKey: key(url, maxPixelSize)) }
        return image
    }

    private static func downsample(url: URL, maxPixelSize: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }

        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize),
        ] as [CFString: Any] as CFDictionary

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}

/// Draws a downsampled on-disk image, falling back to `placeholder` until it
/// has loaded (or if it can't be decoded).
public struct DownsampledImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let maxPixelSize: CGFloat
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var loaded: CGImage?

    public init(
        url: URL?,
        maxPixelSize: CGFloat,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.content = content
        self.placeholder = placeholder
    }

    /// Falls back to the cache synchronously so a cell recreated by a lazy
    /// container shows its image on the first frame instead of flashing.
    private var image: CGImage? {
        if let loaded { return loaded }
        guard let url else { return nil }
        return DownsampledImageLoader.cached(url: url, maxPixelSize: maxPixelSize)
    }

    public var body: some View {
        Group {
            if let image {
                content(Image(decorative: image, scale: 1))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else {
                loaded = nil
                return
            }
            loaded = await DownsampledImageLoader.load(url: url, maxPixelSize: maxPixelSize)
        }
    }
}
