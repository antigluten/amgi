import SwiftUI
import WebKit
import AmgiCardWeb

struct CardWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.setURLSchemeHandler(CardAssetScheme(), forURLScheme: CardAssetPath.scheme)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsVerticalScrollIndicator = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let rewritten = CardHTMLRewriter.rewrite(html)
        let full = MathJaxTemplate.wrap(rewritten)
        let baseURL = URL(string: "\(CardAssetPath.scheme)://card/")
        webView.loadHTMLString(full, baseURL: baseURL)
    }
}
