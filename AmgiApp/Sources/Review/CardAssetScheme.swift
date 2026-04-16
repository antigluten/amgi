import Foundation
import WebKit
import AmgiCardWeb
import Dependencies
import AnkiBackend
import os

final class CardAssetScheme: NSObject, WKURLSchemeHandler {
    private static let logger = Logger(subsystem: "com.amgiapp.AmgiApp", category: "CardAssetScheme")

    private let bundleRoot: String
    private let mediaRootProvider: @Sendable () -> String?

    init(
        bundleRoot: String = Bundle.main.bundlePath,
        mediaRootProvider: @escaping @Sendable () -> String? = {
            @Dependency(\.ankiBackend) var backend
            return backend.currentMediaFolderPath
        }
    ) {
        self.bundleRoot = bundleRoot
        self.mediaRootProvider = mediaRootProvider
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        guard let mediaRoot = mediaRootProvider() else {
            // Transient: collection may not yet be open. Respond 503 rather than
            // failing hard so the WebView's network stack doesn't remember a
            // terminal error.
            respond(task: urlSchemeTask, url: url, statusCode: 503, body: Data())
            return
        }
        guard let filePath = CardAssetPath.resolve(
            url: url, mediaRoot: mediaRoot, bundleRoot: bundleRoot
        ) else {
            urlSchemeTask.didFailWithError(URLError(.noPermissionsToReadFile))
            return
        }
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        } catch {
            Self.logger.error("CardAssetScheme: failed to read \(filePath, privacy: .public): \(error.localizedDescription, privacy: .public)")
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mime = CardAssetPath.mimeType(for: filePath)
        respond(task: urlSchemeTask, url: url, statusCode: 200, body: data, mime: mime)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // Data(contentsOf:) is synchronous; no cancellable work remains once start() returns.
    }

    private func respond(
        task: any WKURLSchemeTask,
        url: URL,
        statusCode: Int,
        body: Data,
        mime: String = "application/octet-stream"
    ) {
        let headers: [String: String] = [
            "Content-Type": mime,
            "Content-Length": "\(body.count)",
        ]
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            task.didFailWithError(URLError(.badServerResponse))
            return
        }
        task.didReceive(response)
        task.didReceive(body)
        task.didFinish()
    }
}
