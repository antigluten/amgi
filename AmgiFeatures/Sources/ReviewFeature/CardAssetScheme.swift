//
//  CardAssetScheme.swift
//  ReviewFeature
//
//  Created by Vladimir Gusev on 16.04.2026.
//

import Foundation
import WebKit
import AmgiCardWeb
import AnkiClients
import Dependencies

@MainActor
final class CardAssetScheme: NSObject, WKURLSchemeHandler {
    /// In-flight asset reads, keyed by task identity.
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    /// Resolved once rather than per request — `@Dependency` lookup was
    /// running on every asset a card referenced.
    @Dependency(\.mediaClient) private var mediaClient

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        let mediaRoot = mediaClient.folderURL()
        let bundleRoot = Bundle.main.resourceURL

        if url.host?.lowercased() == "media", mediaRoot == nil {
            respond(to: urlSchemeTask, url: url, statusCode: 503, mimeType: "text/plain", data: Data())
            return
        }

        // CardAssetPath.resolve only handles 'media' and 'assets' hosts.
        // For 'card' host, we don't serve files—the baseURL is just for relative URL resolution.
        // This is a no-op for card host; links will be handled by JavaScript handlers.
        guard let fileURL = CardAssetPath.resolve(url: url, mediaRoot: mediaRoot, bundleRoot: bundleRoot) else {
            // Not a resolvable asset path (e.g., 'card' host). Respond with 204 (No Content).
            respond(to: urlSchemeTask, url: url, statusCode: 204, mimeType: "text/plain", data: Data())
            return
        }

        // WKURLSchemeHandler callbacks arrive on the main thread, so reading
        // the file inline stalled the UI mid-render for every image, audio
        // file and MathJax asset a card referenced — worst on cold-cache
        // audio. The read moves off-thread; the task is tracked so a stopped
        // task is never resumed (WebKit answers that with an uncatchable
        // NSInternalInconsistencyException).
        let key = ObjectIdentifier(urlSchemeTask)
        let mimeType = CardAssetPath.mimeType(for: fileURL)
        tasks[key] = Task { [weak self] in
            let data = try? await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: fileURL, options: .mappedIfSafe)
            }.value
            guard let self, self.tasks[key] != nil, !Task.isCancelled else { return }
            self.tasks[key] = nil
            if let data {
                self.respond(to: urlSchemeTask, url: url, statusCode: 200, mimeType: mimeType, data: data)
            } else {
                self.respond(to: urlSchemeTask, url: url, statusCode: 404, mimeType: "text/plain", data: Data())
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))?.cancel()
    }
}

private extension CardAssetScheme {
    func respond(
        to task: any WKURLSchemeTask,
        url: URL,
        statusCode: Int,
        mimeType: String,
        data: Data
    ) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mimeType,
                "Content-Length": String(data.count),
                "Cache-Control": "no-cache",
            ]
        ) else {
            task.didFailWithError(URLError(.badServerResponse))
            return
        }

        task.didReceive(response)
        if !data.isEmpty {
            task.didReceive(data)
        }
        task.didFinish()
    }
}
