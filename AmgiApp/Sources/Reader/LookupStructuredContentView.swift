import AmgiReader
import AmgiReaderDictionary
import Dependencies
import SwiftUI
@preconcurrency import WebKit

/// Renders Yomitan-format structured glossaries via a self-sizing
/// WKWebView that hosts the bundled `popup.js` renderer. The web layer
/// owns the visual shape (lists, tables, links, pitch diagrams,
/// dictionary-bundled images) — this Swift wrapper just feeds it the
/// glossary JSON, mediates tap-to-lookup, and resolves `image://` media
/// URLs back to `dictionaryLookupClient.mediaFile`.
struct LookupStructuredContentView: UIViewRepresentable {
    let dictionary: String
    let glossaries: [DictionaryLookupGlossary]
    let dictionaryStyle: String
    let onLookupRequested: ((String) -> Void)?

    @Dependency(\.dictionaryLookupClient) var dictionaryLookupClient

    func makeCoordinator() -> Coordinator {
        Coordinator(
            dictionary: dictionary,
            glossaries: glossaries,
            dictionaryStyle: dictionaryStyle,
            onLookupRequested: onLookupRequested,
            loadMediaData: { dict, mediaPath in
                try await dictionaryLookupClient.mediaFile(dict, mediaPath)
            }
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.setURLSchemeHandler(context.coordinator, forURLScheme: "image")
        configuration.userContentController.add(context.coordinator, name: "openLink")
        configuration.userContentController.add(context.coordinator, name: "lookupText")

        let webView = SizingWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.loadHTMLString(context.coordinator.html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(
            dictionary: dictionary,
            glossaries: glossaries,
            dictionaryStyle: dictionaryStyle
        )
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "openLink")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "lookupText")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKURLSchemeHandler {
        fileprivate var html: String = ""
        fileprivate weak var webView: WKWebView?

        private var dictionary: String
        private var glossaries: [DictionaryLookupGlossary]
        private var dictionaryStyle: String
        private let onLookupRequested: ((String) -> Void)?
        private let loadMediaData: @Sendable (String, String) async throws -> Data

        init(
            dictionary: String,
            glossaries: [DictionaryLookupGlossary],
            dictionaryStyle: String,
            onLookupRequested: ((String) -> Void)?,
            loadMediaData: @escaping @Sendable (String, String) async throws -> Data
        ) {
            self.dictionary = dictionary
            self.glossaries = glossaries
            self.dictionaryStyle = dictionaryStyle
            self.onLookupRequested = onLookupRequested
            self.loadMediaData = loadMediaData
            super.init()
            html = Self.makeHTML(
                dictionary: dictionary,
                glossaries: glossaries,
                dictionaryStyle: dictionaryStyle
            )
        }

        func update(
            dictionary: String,
            glossaries: [DictionaryLookupGlossary],
            dictionaryStyle: String
        ) {
            let next = Self.makeHTML(
                dictionary: dictionary,
                glossaries: glossaries,
                dictionaryStyle: dictionaryStyle
            )
            guard next != html else { return }
            self.dictionary = dictionary
            self.glossaries = glossaries
            self.dictionaryStyle = dictionaryStyle
            html = next
            webView?.loadHTMLString(next, baseURL: nil)
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateContentHeight(for: webView)
            // Initial layout pass settles a beat after didFinish; re-poll
            // a couple of times so the intrinsic-size invalidation
            // catches the post-layout height. Mirrors DreamAfar.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak webView] in
                guard let webView else { return }
                self.updateContentHeight(for: webView)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak webView] in
                guard let webView else { return }
                self.updateContentHeight(for: webView)
            }
        }

        private func updateContentHeight(for webView: WKWebView) {
            let script = """
            Math.ceil(document.getElementById('content')?.getBoundingClientRect().height || 0)
            """
            webView.evaluateJavaScript(script) { value, _ in
                guard let n = value as? NSNumber,
                      let sizing = webView as? SizingWebView else { return }
                sizing.setContentHeight(CGFloat(truncating: n))
            }
        }

        // MARK: WKScriptMessageHandler

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "lookupText":
                guard let payload = message.body as? [String: Any],
                      let text = (payload["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty else { return }
                onLookupRequested?(text)
            case "openLink":
                guard let urlString = message.body as? String,
                      let url = URL(string: urlString) else { return }
                UIApplication.shared.open(url)
            default:
                return
            }
        }

        // MARK: WKURLSchemeHandler — dictionary-bundled media via image://

        func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
            guard let requestURL = urlSchemeTask.request.url,
                  let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
                  let dict = components.queryItems?.first(where: { $0.name == "dictionary" })?.value,
                  let mediaPath = components.queryItems?.first(where: { $0.name == "path" })?.value else {
                urlSchemeTask.didFailWithError(URLError(.badURL))
                return
            }
            Task {
                do {
                    let data = try await loadMediaData(dict, mediaPath)
                    guard !data.isEmpty else {
                        urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
                        return
                    }
                    let response = URLResponse(
                        url: requestURL,
                        mimeType: Self.mimeType(for: mediaPath),
                        expectedContentLength: data.count,
                        textEncodingName: nil
                    )
                    urlSchemeTask.didReceive(response)
                    urlSchemeTask.didReceive(data)
                    urlSchemeTask.didFinish()
                } catch {
                    urlSchemeTask.didFailWithError(error)
                }
            }
        }

        func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

        // MARK: HTML

        private static func makeHTML(
            dictionary: String,
            glossaries: [DictionaryLookupGlossary],
            dictionaryStyle: String
        ) -> String {
            let dictionaryData = (try? JSONEncoder().encode(glossaries))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let escapedDictionary = dictionary
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            // Backticks would close the template literal we drop the
            // dictionary CSS into below — escape them.
            let escapedStyle = dictionaryStyle
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")

            return """
            <!doctype html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
            <style>\(ReaderLookupStructuredContentResources.popupCSS)</style>
            <script>\(ReaderLookupStructuredContentResources.popupJS)</script>
            <style>
            body { padding: 0; margin: 0; }
            #content { padding: 0; }
            .glossary-content { padding: 0; }
            </style>
            </head>
            <body>
            <div id="content" data-dictionary="\(escapedDictionary)"></div>
            <script>
            (function() {
                const dictName = "\(escapedDictionary)";
                const glossaryItems = \(dictionaryData);
                window.dictionaryStyles = { [dictName]: `\(escapedStyle)` };
                window.compactGlossaries = false;

                const contentRoot = document.getElementById('content');
                const dictStyle = window.dictionaryStyles?.[dictName] ?? '';
                if (dictStyle) {
                    const style = document.createElement('style');
                    style.textContent = constructDictCss(dictStyle, dictName);
                    document.head.appendChild(style);
                }

                const termTags = [...new Set(parseTags(glossaryItems[0]?.termTags))];
                const termTagsRow = createGlossaryTags(termTags);
                if (termTagsRow) {
                    contentRoot.appendChild(termTagsRow);
                }

                const renderContent = (parent, content) => {
                    try {
                        renderStructuredContent(parent, JSON.parse(content), null, dictName);
                    } catch {
                        renderStructuredContent(parent, content, null, dictName);
                    }
                };

                if (glossaryItems.length > 1) {
                    const ol = el('ol');
                    glossaryItems.forEach((item) => {
                        const li = el('li');
                        const parsedTags = parseTags(item.definitionTags).filter(tag => !NUMERIC_TAG.test(tag));
                        const tags = createGlossaryTags(parsedTags);
                        if (tags) li.appendChild(tags);
                        const wrapper = el('div', { className: 'glossary-content' });
                        renderContent(wrapper, item.content);
                        li.appendChild(wrapper);
                        ol.appendChild(li);
                    });
                    contentRoot.appendChild(ol);
                } else {
                    glossaryItems.forEach((item, index) => {
                        const wrapper = el('div');
                        const tags = createGlossaryTags(parseTags(item.definitionTags).filter(tag => !NUMERIC_TAG.test(tag)));
                        if (tags) wrapper.appendChild(tags);
                        const content = el('div', { className: 'glossary-content' });
                        renderContent(content, item.content);
                        wrapper.appendChild(content);
                        if (index > 0) contentRoot.appendChild(document.createElement('hr'));
                        contentRoot.appendChild(wrapper);
                    });
                }
            })();
            </script>
            </body>
            </html>
            """
        }

        private static func mimeType(for path: String) -> String {
            switch URL(fileURLWithPath: path).pathExtension.lowercased() {
            case "png": return "image/png"
            case "jpg", "jpeg": return "image/jpeg"
            case "gif": return "image/gif"
            case "webp": return "image/webp"
            case "avif": return "image/avif"
            case "heic": return "image/heic"
            case "svg": return "image/svg+xml"
            default: return "application/octet-stream"
            }
        }
    }
}

/// Self-sizing WKWebView. WebKit doesn't report its own intrinsic size,
/// so we poll content height after navigation and republish as
/// `intrinsicContentSize` — SwiftUI's layout then sizes the View to
/// match without forcing the user to scroll a nested scroll view.
private final class SizingWebView: WKWebView {
    private var contentHeight: CGFloat = 44 {
        didSet { invalidateIntrinsicContentSize() }
    }

    func setContentHeight(_ height: CGFloat) {
        let resolved = max(44, ceil(height))
        guard abs(resolved - contentHeight) > 0.5 else { return }
        contentHeight = resolved
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: max(44, contentHeight))
    }
}
