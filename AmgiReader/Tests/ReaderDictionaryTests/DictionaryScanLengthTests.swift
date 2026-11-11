import Foundation
import Reader
import Testing
import WebKit
@testable import ReaderDictionary

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct DictionaryScanLengthTests {
    @Test(arguments: [
        "<p>先生は来た。</p>",
        "<p><span>先</span>生は来た。</p>",
        "<p><ruby>先生<rt>せんせい</rt></ruby>は来た。</p>",
    ])
    func tappedTextReachesNativeDictionary(body: String) async throws {
        let profileID = "scan-length-test-" + UUID().uuidString
        let directory = try #require(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
            .appendingPathComponent("ReaderDictionaries").appendingPathComponent(profileID)
        defer { try? FileManager.default.removeItem(at: directory) }
        let runtime = DictionaryLookupRuntime(configStore: .testValue, profileID: profileID)
        let archive = try #require(Bundle.module.url(forResource: "scan-length", withExtension: "zip", subdirectory: "Fixtures"))
        _ = try await runtime.importArchive(at: archive, kind: .term, requiresSecurityScope: false)
        let page = DictionaryPage()
        try await page.load(body)

        for (scanLength, expected) in [(1, "先"), (2, "先生"), (16, "先生")] {
            let query = try #require(try await page.query(scanLength: scanLength))
            let result = try await runtime.lookup(query, maxResults: 1, scanLength: scanLength)
            let entry = try #require(result.entries.first)
            #expect(entry.term == expected)
            #expect(entry.matched == expected)
            #expect(entry.glossaries.contains { $0.contains(expected == "先生" ? "teacher" : "ahead") })
        }
    }
}

private struct WebContentTerminated: Error {}

@MainActor
private final class DictionaryPage: NSObject, WKNavigationDelegate {
    private let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
    private var loaded: CheckedContinuation<Void, any Error>?

    func load(_ body: String) async throws {
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            loaded = continuation
            webView.loadHTMLString("""
                <html><head><meta charset="utf-8"><style>body { font-size: 24px; }</style>
                <script>\(LookupExtractionScript.source)</script></head><body>\(body)</body></html>
                """, baseURL: nil)
        }
    }

    func query(scanLength: Int) async throws -> String? {
        try await webView.evaluateJavaScript("""
            (() => {
              const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
              let node;
              while ((node = walker.nextNode())) {
                if (!node.textContent.startsWith('先')) continue;
                const range = document.createRange();
                range.setStart(node, 0); range.setEnd(node, 1);
                const rect = range.getBoundingClientRect();
                const payload = window.amgiLookup.payloadAt(rect.left + rect.width / 2, rect.top + rect.height / 2, \(scanLength));
                return payload ? payload.text : null;
              }
              return null;
            })()
            """) as? String
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded?.resume()
        loaded = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        loaded?.resume(throwing: error)
        loaded = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        loaded?.resume(throwing: error)
        loaded = nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loaded?.resume(throwing: WebContentTerminated())
        loaded = nil
    }
}
