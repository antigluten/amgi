import Foundation
import WebKit
import AmgiCardWeb
import AnkiBackend
import Dependencies

final class CardAssetScheme: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        @Dependency(\.ankiBackend) var backend
        let mediaRoot: URL? = {
            guard let path = backend.currentMediaFolderPath else { return nil }
            return URL(fileURLWithPath: path)
        }()
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

        do {
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            respond(
                to: urlSchemeTask,
                url: url,
                statusCode: 200,
                mimeType: CardAssetPath.mimeType(for: fileURL),
                data: data
            )
        } catch {
            respond(to: urlSchemeTask, url: url, statusCode: 404, mimeType: "text/plain", data: Data())
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    private func respond(
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
