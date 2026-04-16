public import Foundation

public enum CardAssetPath {
    public static let scheme = "amgi-asset"

    /// Resolves an `amgi-asset://` URL to an absolute file path on disk, or nil
    /// if the URL is malformed, targets an unknown host, attempts path
    /// traversal outside the allowed root, or points to an asset subdirectory
    /// we do not serve.
    public static func resolve(url: URL, mediaRoot: String, bundleRoot: String) -> String? {
        guard url.scheme == scheme, let host = url.host else { return nil }

        // `URL.path` returns a percent-decoded path.
        let rawPath = url.path
        let relative = rawPath.hasPrefix("/") ? String(rawPath.dropFirst()) : rawPath
        guard !relative.isEmpty else { return nil }

        switch host {
        case "media":
            return resolved(root: mediaRoot, relative: relative)
        case "assets":
            guard relative.hasPrefix("mathjax/") else { return nil }
            return resolved(root: bundleRoot, relative: relative)
        default:
            return nil
        }
    }

    /// Maps a filename extension to a MIME type. Falls back to
    /// `application/octet-stream` for unknown or missing extensions.
    public static func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp3": return "audio/mpeg"
        case "mp4": return "video/mp4"
        case "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        case "ogg": return "audio/ogg"
        case "opus": return "audio/ogg"
        case "flac": return "audio/flac"
        case "aac": return "audio/aac"
        case "webm": return "video/webm"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "heic": return "image/heic"
        case "tif", "tiff": return "image/tiff"
        case "svg": return "image/svg+xml"
        case "js": return "application/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "html", "htm": return "text/html"
        default: return "application/octet-stream"
        }
    }

    private static func resolved(root: String, relative: String) -> String? {
        // standardizedFileURL resolves `..` textually but NOT symlinks. A malicious
        // .apkg could plant a symlink inside the media folder pointing outside of
        // it. resolvingSymlinksInPath realizes symlinks so the prefix check below
        // sees the true target.
        let rootURL = URL(fileURLWithPath: root).standardizedFileURL.resolvingSymlinksInPath()
        let combined = URL(fileURLWithPath: root)
            .appendingPathComponent(relative)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let rootPath = rootURL.path
        let combinedPath = combined.path
        guard combinedPath == rootPath || combinedPath.hasPrefix(rootPath + "/") else {
            return nil
        }
        return combinedPath
    }
}
