import Foundation
import UIKit
import WebKit

/// Per-chapter content payload handed to the page controller. The host
/// rebuilds this whenever the user crosses a chapter boundary.
struct EPUBChapterContent: Equatable {
    let chapterID: Int64
    /// On-disk URL of the chapter XHTML inside the book's extracted
    /// directory. The WebView is granted read-access to `readAccessURL`
    /// (the book's extracted root) so referenced CSS/images resolve.
    let contentURL: URL
    /// Root the WebView gets `loadFileURL` read-access to.
    let readAccessURL: URL
}

/// CSS tokens passed from SwiftUI prefs into the injected stylesheet.
/// Reused as `--reader-*` custom properties in `EPUBReaderStyles.css`.
/// New typography settings (`fontFamilyCSS`, `pageMarginPx`, `textAlign`,
/// `tokenUnderlineCSS`) come from `ReaderTypographyPreferences`; the
/// legacy fields are kept for the per-book settings panel.
struct EPUBReaderStyleTokens: Equatable {
    var foreground: String = "#1f2a26"
    var background: String = "#faf7f2"
    var fontSizePx: Int = 17
    var lineHeight: Double = 1.55
    var paddingPx: Int = 22
    var verticalMode: Bool = false
    var fontFamilyCSS: String = "-apple-system, BlinkMacSystemFont, \"Helvetica Neue\", sans-serif"
    var pageMarginPx: Int = 24
    var textAlign: String = "justify"
    var tokenUnderlineCSS: String = "rgba(120, 120, 120, 0.55)"
}

/// Callbacks emitted by a chapter page back up to the host coordinator.
@MainActor
protocol EPUBChapterPageControllerDelegate: AnyObject {
    func epubChapter(_ controller: EPUBChapterPageController, didReportPageInfoIndex pageIndex: Int, pageCount: Int)
    func epubChapter(_ controller: EPUBChapterPageController, didReportProgressFraction fraction: Double, pageIndex: Int)
    func epubChapter(_ controller: EPUBChapterPageController, didTapWord token: String, sentence: String)
    func epubChapterDidTapEmptySpace(_ controller: EPUBChapterPageController, atRelativeX relativeX: CGFloat)
}

/// Hosts one chapter's WKWebView, configured for native UIScrollView
/// paging over the CSS multi-column layout. Reports page info, progress,
/// and word taps via `EPUBChapterPageControllerDelegate`.
@MainActor
final class EPUBChapterPageController: UIViewController {
    let chapterIndex: Int
    let content: EPUBChapterContent
    var styleTokens: EPUBReaderStyleTokens
    /// 0..1 fraction to scroll to once a freshly-loaded chapter reports
    /// its page count. Consumed and cleared inside the bridge.
    private(set) var pendingRestoreFraction: Double?

    weak var pageDelegate: EPUBChapterPageControllerDelegate?

    private var webView: WKWebView!
    private var bridge: ScriptBridge!
    /// Last viewport size pushed to CSS. Used to detect real layout
    /// changes (rotation, safe-area updates) so we don't trigger a
    /// relayout for every spurious `viewDidLayoutSubviews` tick.
    private var lastPushedPageSize: CGSize = .zero
    /// Whether the WebView has finished its initial navigation. Until
    /// then `evaluateJavaScript` calls targeting `__amgiRelayout` are
    /// silently dropped — we let `webView(_:didFinish:)` push the first
    /// layout instead.
    private var didFinishInitialLoad: Bool = false

    init(
        chapterIndex: Int,
        content: EPUBChapterContent,
        styleTokens: EPUBReaderStyleTokens,
        pendingRestoreFraction: Double?
    ) {
        self.chapterIndex = chapterIndex
        self.content = content
        self.styleTokens = styleTokens
        self.pendingRestoreFraction = pendingRestoreFraction
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let config = WKWebViewConfiguration()
        let userContent = WKUserContentController()

        if let css = Self.bundledCSS() {
            let cssScript = WKUserScript(
                source: Self.injectStyleSnippet(css: css),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            userContent.addUserScript(cssScript)
        }
        if let js = Self.bundledJS() {
            let jsScript = WKUserScript(
                source: js,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            userContent.addUserScript(jsScript)
        }

        bridge = ScriptBridge(owner: self)
        userContent.add(bridge, name: "pageInfo")
        userContent.add(bridge, name: "progress")
        userContent.add(bridge, name: "wordTap")

        config.userContentController = userContent
        config.suppressesIncrementalRendering = false
        config.defaultWebpagePreferences.preferredContentMode = .mobile

        let webView = WKWebView(frame: .zero, configuration: config)
        // Native paging: UIScrollView snaps each column-width to a page.
        // This is the same gesture engine Apple Books uses.
        webView.scrollView.isPagingEnabled = true
        webView.scrollView.decelerationRate = .fast
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.delegate = bridge
        webView.navigationDelegate = bridge
        webView.isOpaque = false
        webView.backgroundColor = .clear

        // Tap-empty-space recogniser for chrome toggle. Set to fail when
        // the WebView's own tap (word lookup) succeeds; the JS click
        // handler stops propagation up here when a token is hit.
        let tap = UITapGestureRecognizer(target: bridge, action: #selector(ScriptBridge.handleEmptyTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = bridge
        webView.addGestureRecognizer(tap)

        self.webView = webView
        self.view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyHostBackgroundColor()
        webView.loadFileURL(content.contentURL, allowingReadAccessTo: content.readAccessURL)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pushPageSizeIfChanged()
    }

    /// Push the WKWebView's current viewport size into CSS as
    /// `--page-width` / `--page-height`, then call `__amgiRelayout` to
    /// reflow the column container and re-snap to the saved page index.
    /// Skips pushes when the size hasn't changed or before the first
    /// navigation completes (the JS hook isn't wired yet).
    fileprivate func pushPageSizeIfChanged(force: Bool = false) {
        guard didFinishInitialLoad else { return }
        let size = webView.scrollView.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        if !force, size == lastPushedPageSize { return }

        let previousPageWidth = lastPushedPageSize.width
        let currentOffsetX = webView.scrollView.contentOffset.x
        let previousIndex: Int
        if previousPageWidth > 0 {
            previousIndex = Int(round(currentOffsetX / previousPageWidth))
        } else {
            previousIndex = 0
        }

        lastPushedPageSize = size

        // JS owns --page-width / --page-height (driven from window.innerWidth
        // / innerHeight inside __amgiRelayout → syncPageVars). Swift only
        // pokes the relayout hook so we re-snap to the right column after
        // rotation or safe-area changes.
        let js = """
        (function() {
          var n = (typeof window.__amgiRelayout === 'function') ? window.__amgiRelayout() : 1;
          return n;
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] _, _ in
            guard let self else { return }
            // Re-snap to the previously-current page after the relayout
            // settles. Done in the next runloop tick so the new
            // contentSize.width has propagated to the scroll view.
            DispatchQueue.main.async {
                let newWidth = self.webView.scrollView.bounds.width
                guard newWidth > 0 else { return }
                let target = CGFloat(previousIndex) * newWidth
                let maxX = max(0, self.webView.scrollView.contentSize.width - newWidth)
                self.webView.scrollView.setContentOffset(
                    CGPoint(x: min(target, maxX), y: 0),
                    animated: false
                )
            }
        }
    }

    fileprivate func applyHostBackgroundColor() {
        let cgColor = UIColor.color(fromHex: styleTokens.background) ?? .systemBackground
        webView.backgroundColor = cgColor
        webView.scrollView.backgroundColor = cgColor
        view.backgroundColor = cgColor
    }

    /// Update style tokens on an already-loaded chapter (e.g. user
    /// changed font size while in the same chapter).
    func update(styleTokens: EPUBReaderStyleTokens) {
        self.styleTokens = styleTokens
        applyStyleTokens()
    }

    fileprivate func markInitialLoadFinished() {
        didFinishInitialLoad = true
    }

    /// Programmatic jump used by the host coordinator (edge-tap zones).
    func paginate(direction: PageDirection) {
        let scroll = webView.scrollView
        let viewport = max(1, scroll.bounds.width)
        let currentIndex = Int(round(scroll.contentOffset.x / viewport))
        let nextIndex: Int
        switch direction {
        case .forward: nextIndex = currentIndex + 1
        case .backward: nextIndex = currentIndex - 1
        }
        let maxIndex = max(0, Int(round(scroll.contentSize.width / viewport)) - 1)
        let clamped = min(max(nextIndex, 0), maxIndex)
        scroll.setContentOffset(CGPoint(x: CGFloat(clamped) * viewport, y: 0), animated: true)
    }

    enum PageDirection {
        case forward, backward
    }

    /// True when the user is on the last column of this chapter. Used by
    /// the host to suppress the next-chapter dataSource entry only when
    /// the inner scrollview is already at the edge — but the architect
    /// plan relies on default UIKit arbitration, so this stays
    /// diagnostic only.
    var isAtLastPage: Bool {
        let scroll = webView.scrollView
        let viewport = max(1, scroll.bounds.width)
        let last = max(0, Int(round(scroll.contentSize.width / viewport)) - 1)
        let current = Int(round(scroll.contentOffset.x / viewport))
        return current >= last
    }

    var isAtFirstPage: Bool {
        webView.scrollView.contentOffset.x <= 1
    }

    fileprivate func applyStyleTokens() {
        let mode = styleTokens.verticalMode ? "vertical-rl" : "horizontal-tb"
        let escapedFontFamily = styleTokens.fontFamilyCSS
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function() {
          var r = document.documentElement;
          r.style.setProperty('--reader-fg', '\(styleTokens.foreground)');
          r.style.setProperty('--reader-bg', '\(styleTokens.background)');
          r.style.setProperty('--reader-font-size', '\(styleTokens.fontSizePx)px');
          r.style.setProperty('--reader-line-height', '\(styleTokens.lineHeight)');
          r.style.setProperty('--reader-padding', '\(styleTokens.paddingPx)px');
          r.style.setProperty('--reader-page-margin', '\(styleTokens.pageMarginPx)px');
          r.style.setProperty('--reader-page-padding', '\(styleTokens.paddingPx)px');
          r.style.setProperty('--reader-writing-mode', '\(mode)');
          r.style.setProperty('--reader-font-family', '\(escapedFontFamily)');
          r.style.setProperty('--reader-text-align', '\(styleTokens.textAlign)');
          r.style.setProperty('--reader-tok-underline', '\(styleTokens.tokenUnderlineCSS)');
          if (typeof window.__amgiRelayout === 'function') { window.__amgiRelayout(); }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
        applyHostBackgroundColor()
    }

    fileprivate func consumePendingRestore() {
        guard let fraction = pendingRestoreFraction else { return }
        pendingRestoreFraction = nil
        let delay = DispatchTime.now() + 0.25
        DispatchQueue.main.asyncAfter(deadline: delay) { [weak self] in
            guard let webView = self?.webView else { return }
            webView.evaluateJavaScript("window.__amgiScrollToFraction(\(fraction));", completionHandler: nil)
        }
    }

}

private extension EPUBChapterPageController {
    // MARK: - Bundle resource loading

    static func bundledCSS() -> String? {
        let url = Bundle.main.url(forResource: "EPUBReaderStyles", withExtension: "css", subdirectory: "EPUBReader")
            ?? Bundle.main.url(forResource: "EPUBReaderStyles", withExtension: "css")
        guard let url else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func bundledJS() -> String? {
        let url = Bundle.main.url(forResource: "EPUBReaderInjection", withExtension: "js", subdirectory: "EPUBReader")
            ?? Bundle.main.url(forResource: "EPUBReaderInjection", withExtension: "js")
        guard let url else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func injectStyleSnippet(css: String) -> String {
        let escaped = css.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        // The book may ship <link rel="stylesheet"> nodes that load
        // asynchronously and would otherwise win the cascade against
        // our injected variables/overrides. We append our <style> as
        // the LAST child of <head> (so it wins on document order at
        // equal specificity), and re-append it after `window.load`
        // and on a one-tick microtask so any late-arriving book
        // stylesheets can't override us.
        return """
        (function() {
          function place() {
            var existing = document.querySelector('style[data-amgi="reader"]');
            var s = existing || document.createElement('style');
            if (!existing) {
              s.setAttribute('data-amgi', 'reader');
              s.textContent = `\(escaped)`;
            }
            var head = document.head || document.documentElement;
            // Re-append moves the node to the end of head's child list.
            head.appendChild(s);
          }
          place();
          setTimeout(place, 0);
          if (document.readyState === 'complete') {
            setTimeout(place, 0);
          } else {
            window.addEventListener('load', function() { setTimeout(place, 0); }, { once: true });
          }
        })();
        """
    }
}

// MARK: - Script + scroll bridge

/// Bridges WKScriptMessageHandler, WKNavigationDelegate, UIScrollViewDelegate,
/// and the empty-tap recogniser. Held by the chapter VC (which owns the
/// WebView), so its lifetime tracks the chapter page.
@MainActor
final class ScriptBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate,
                          UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private weak var owner: EPUBChapterPageController?

    init(owner: EPUBChapterPageController) {
        self.owner = owner
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        owner?.markInitialLoadFinished()
        // Push viewport size first so the CSS column container is sized
        // correctly *before* applyStyleTokens triggers a relayout. Then
        // apply theme + typography, then restore saved progress.
        owner?.pushPageSizeIfChanged(force: true)
        owner?.applyStyleTokens()
        owner?.consumePendingRestore()
    }

    // MARK: WKScriptMessageHandler

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // WebKit delivers script messages on the main thread; message.name /
        // .body are @MainActor. assumeIsolated reads them and dispatches
        // synchronously — no Task hop needed.
        MainActor.assumeIsolated {
            self.handle(name: message.name, body: message.body)
        }
    }

    // MARK: UIScrollViewDelegate (page bookkeeping)

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y != 0 {
            scrollView.contentOffset.y = 0
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        emitPageInfo(scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { emitPageInfo(scrollView) }
    }

    // MARK: Empty-tap recogniser

    @objc
    func handleEmptyTap(_ recognizer: UITapGestureRecognizer) {
        guard let owner, let view = recognizer.view else { return }
        let location = recognizer.location(in: view)
        let relativeX = view.bounds.width > 0 ? location.x / view.bounds.width : 0.5
        owner.pageDelegate?.epubChapterDidTapEmptySpace(owner, atRelativeX: relativeX)
    }

    nonisolated func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Let the WebView's internal recognisers run alongside ours so
        // word taps + horizontal swipes still function.
        true
    }
}

private extension ScriptBridge {
    func handle(name: String, body: Any) {
        guard let owner else { return }
        switch name {
        case "pageInfo":
            guard let dict = body as? [String: Any],
                  let pageIndex = dict["pageIndex"] as? Int,
                  let pageCount = dict["pageCount"] as? Int else { return }
            owner.pageDelegate?.epubChapter(owner, didReportPageInfoIndex: pageIndex, pageCount: pageCount)
        case "progress":
            // progress events only update the progress fraction.
            // UIScrollViewDelegate (emitPageInfo) is the single source of
            // truth for pageIndex / pageCount — emitting them from here
            // too caused the host counter to flicker during a swipe.
            guard let dict = body as? [String: Any],
                  let pageIndex = dict["pageIndex"] as? Int,
                  let fraction = dict["progressFraction"] as? Double else { return }
            owner.pageDelegate?.epubChapter(owner, didReportProgressFraction: fraction, pageIndex: pageIndex)
        case "wordTap":
            guard let dict = body as? [String: Any] else { return }
            let token = (dict["token"] as? String) ?? ""
            let sentence = (dict["sentence"] as? String) ?? token
            guard !token.isEmpty else { return }
            owner.pageDelegate?.epubChapter(owner, didTapWord: token, sentence: sentence)
        default:
            break
        }
    }

    func emitPageInfo(_ scrollView: UIScrollView) {
        guard let owner else { return }
        let viewport = max(1, scrollView.bounds.width)
        let pageIndex = Int(round(scrollView.contentOffset.x / viewport))
        let totalPages = max(1, Int(round(scrollView.contentSize.width / viewport)))
        owner.pageDelegate?.epubChapter(owner, didReportPageInfoIndex: pageIndex, pageCount: totalPages)
        let denom = Double(max(1, totalPages - 1))
        let fraction = min(1, max(0, Double(pageIndex) / denom))
        owner.pageDelegate?.epubChapter(owner, didReportProgressFraction: fraction, pageIndex: pageIndex)
    }
}

// MARK: - Hex → UIColor

extension UIColor {
    /// Parse "#RRGGBB" or "#RRGGBBAA" (case-insensitive) into a UIColor.
    /// Returns nil for malformed input — caller falls back to a system
    /// colour to avoid a white flash.
    static func color(fromHex hex: String) -> UIColor? {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard let value = UInt64(trimmed, radix: 16) else { return nil }
        switch trimmed.count {
        case 6:
            let r = CGFloat((value & 0xFF0000) >> 16) / 255
            let g = CGFloat((value & 0x00FF00) >> 8) / 255
            let b = CGFloat(value & 0x0000FF) / 255
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        case 8:
            let r = CGFloat((value & 0xFF000000) >> 24) / 255
            let g = CGFloat((value & 0x00FF0000) >> 16) / 255
            let b = CGFloat((value & 0x0000FF00) >> 8) / 255
            let a = CGFloat(value & 0x000000FF) / 255
            return UIColor(red: r, green: g, blue: b, alpha: a)
        default:
            return nil
        }
    }
}
