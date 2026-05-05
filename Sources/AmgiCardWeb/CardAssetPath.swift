public import Foundation
import UniformTypeIdentifiers

public enum CardAssetPath {
    public static let scheme = "amgi-asset"
    public static let cardBaseURL = URL(string: "amgi-asset://card/")!
    public static let mediaBaseURL = URL(string: "amgi-asset://media/")!
    public static let mathJaxConfigScriptURLString = "amgi-asset://assets/mathjax/mathjax.js"
    public static let mathJaxCoreScriptURLString = "amgi-asset://assets/mathjax/vendor/tex-chtml-full.js"

    public static func mediaBaseTag() -> String {
        #"<base href="amgi-asset://media/">"#
    }

    public static func resolve(url: URL, mediaRoot: URL?, bundleRoot: URL?) -> URL? {
        guard url.scheme?.lowercased() == scheme,
              let host = url.host?.lowercased() else {
            return nil
        }

        let relativePath = normalizedRelativePath(from: url)
        switch host {
        case "media":
            guard let mediaRoot else { return nil }
            return resolved(root: mediaRoot, relativePath: relativePath)
        case "assets":
            guard relativePath.hasPrefix("mathjax/") else { return nil }
            return resolvedMathJaxAsset(relativePath: relativePath, preferredRoot: bundleRoot)
        default:
            return nil
        }
    }

    public static func mimeType(for fileURL: URL) -> String {
        if let type = UTType(filenameExtension: fileURL.pathExtension),
           let mimeType = type.preferredMIMEType {
            return mimeType
        }

        switch fileURL.pathExtension.lowercased() {
        case "js":
            return "application/javascript"
        case "css":
            return "text/css"
        case "svg":
            return "image/svg+xml"
        case "woff":
            return "font/woff"
        case "woff2":
            return "font/woff2"
        default:
            return "application/octet-stream"
        }
    }

    private static func normalizedRelativePath(from url: URL) -> String {
        var path = url.path(percentEncoded: true)
        if path.hasPrefix("/") {
            path.removeFirst()
        }
        return path.removingPercentEncoding ?? path
    }

    private static func resolvedMathJaxAsset(relativePath: String, preferredRoot: URL?) -> URL? {
        let candidateRelativePaths = [
            relativePath,
            "Sources/\(relativePath)",
        ]

        for root in mathJaxSearchRoots(preferredRoot: preferredRoot) {
            for candidateRelativePath in candidateRelativePaths {
                if let candidate = resolved(root: root, relativePath: candidateRelativePath),
                   FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return nil
    }

    private static func mathJaxSearchRoots(preferredRoot: URL?) -> [URL] {
        let bundles = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks
        let roots = [preferredRoot, Bundle.main.resourceURL] + bundles.flatMap { bundle in
            [bundle.resourceURL, bundle.bundleURL]
        }

        var seen = Set<String>()
        var uniqueRoots: [URL] = []

        for root in roots {
            guard let root else { continue }
            let standardizedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
            let key = standardizedRoot.path
            guard seen.insert(key).inserted else { continue }
            uniqueRoots.append(standardizedRoot)
        }

        return uniqueRoots
    }

    private static func resolved(root: URL, relativePath: String) -> URL? {
        guard !relativePath.isEmpty else { return nil }

        let rootURL = root.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = rootURL
            .appendingPathComponent(relativePath, isDirectory: false)
            .standardizedFileURL
            .resolvingSymlinksInPath()

        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        let candidatePath = candidate.path
        guard candidatePath == rootURL.path || candidatePath.hasPrefix(rootPath) else {
            return nil
        }

        return candidate
    }
}
