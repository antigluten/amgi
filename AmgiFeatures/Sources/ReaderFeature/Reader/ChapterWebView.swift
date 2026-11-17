//
//  ChapterWebView.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import Reader
import Theme
import AppCore
import Sharing
import SwiftUI
import WebKit

struct ChapterWebView: UIViewRepresentable {
    let html: String
    /// 0..1 fraction to scroll to once the page finishes loading. Read once
    /// per appearance — set to nil after the initial restore.
    let initialProgress: Double?
    @Binding var progress: Double
    /// Vertical (`vertical-rl`) text scrolls sideways, starting at the
    /// right edge, so progress runs along the other axis.
    var verticalLayout = false
    /// Called with a tapped phrase (the engine does its own deinflection
    /// and word-segmentation, so we forward a generous chunk starting at
    /// the tap point rather than a pre-extracted word — handles CJK,
    /// where word boundaries don't exist at the DOM level). nil disables
    /// the tap gesture entirely (controlled by the user pref).
    let onTapLookup: ((String) -> Void)?
    /// Called with the user's current text selection when the toolbar
    /// "make note" button fires the `.amgiReaderRequestSelection`
    /// notification. nil ignores the request.
    let onSelectionForNote: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            progress: $progress,
            onTapLookup: onTapLookup,
            onSelectionForNote: onSelectionForNote
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContent = WKUserContentController()
        if onTapLookup != nil {
            userContent.add(context.coordinator, name: "amgiLookup")
            userContent.addUserScript(WKUserScript(
                source: tapScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            ))
        }
        config.userContentController = userContent

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.isOpaque = false
        context.coordinator.attach(webView: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.pendingInitialProgress = initialProgress
        context.coordinator.verticalLayout = verticalLayout
        // The host builds the HTML in a `.task`, so the very first update
        // arrives empty. Loading it would flash a blank document before the
        // real one lands one runloop later.
        guard !html.isEmpty else { return }
        if context.coordinator.loadedHTML != html {
            context.coordinator.loadedHTML = html
            context.coordinator.didFinishLoad = false
            context.coordinator.didApplyInitialProgress = false
            webView.loadHTMLString(html, baseURL: nil)
        } else {
            // The saved progress now resolves asynchronously, so it can
            // land after `didFinish` — apply it late, once per load.
            context.coordinator.applyPendingInitialProgressIfLoaded()
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
    }

    /// Single-tap → grab a clean phrase starting at the tap caret and
    /// post it to native. Long-press still triggers WKWebView's native
    /// selection so copy/paste keeps working. Skip when there's an
    /// active selection so tapping to dismiss the selection doesn't
    /// also fire a lookup.
    ///
    /// The phrase is cut at the next sentence boundary using `Intl.Segmenter`
    /// when available — this gives the dictionary engine a complete clause
    /// (typically a few words / a clause) to scan rather than an arbitrary
    /// 32-char window that often splits a Hangul/CJK token mid-character.
    /// Falls back to the legacy 32-char chunk on browsers without Segmenter
    /// (mostly old WebKit; current iOS WKWebView ships it).
    private var tapScript: String {
        """
        document.addEventListener('click', function(e) {
          const sel = window.getSelection();
          if (sel && sel.toString().length > 0) { return; }
          const range = document.caretRangeFromPoint(e.clientX, e.clientY);
          if (!range) { return; }

          // Walk forward through text nodes from the tap caret until we
          // have enough characters for the segmenter to find a sentence
          // boundary. 96 is generous — Segmenter cuts at the first
          // boundary anyway, and the engine's scanLength still caps the
          // match.
          let phrase = '';
          let node = range.startContainer;
          let offset = range.startOffset;
          while (node && phrase.length < 96) {
            if (node.nodeType === Node.TEXT_NODE) {
              const t = node.nodeValue || '';
              phrase += t.substring(offset);
              offset = 0;
            }
            if (node.firstChild) {
              node = node.firstChild;
            } else {
              while (node && !node.nextSibling) { node = node.parentNode; }
              node = node && node.nextSibling;
            }
          }
          phrase = phrase.replace(/\\s+/g, ' ').trim();
          if (phrase.length === 0) { return; }

          // Trim to the first sentence using Intl.Segmenter — gives the
          // engine a complete clause without trailing junk. Locale
          // `und` lets the runtime pick rules per script.
          if (typeof Intl !== 'undefined' && Intl.Segmenter) {
            try {
              const seg = new Intl.Segmenter('und', { granularity: 'sentence' });
              const first = seg.segment(phrase)[Symbol.iterator]().next();
              if (first.value && first.value.segment) {
                phrase = first.value.segment.trim();
              }
            } catch (err) {
              // Fall through with the raw phrase.
            }
          }

          if (phrase.length > 0) {
            window.webkit.messageHandlers.amgiLookup.postMessage(phrase);
          }
        }, true);
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate, WKScriptMessageHandler {
        var pendingInitialProgress: Double?
        var loadedHTML: String?
        var didFinishLoad = false
        var didApplyInitialProgress = false
        var verticalLayout = false
        /// The restored position, held while the page is still laying out.
        private var restoreTarget: Double?
        @Binding var progress: Double
        let onTapLookup: ((String) -> Void)?
        let onSelectionForNote: ((String) -> Void)?
        private weak var webView: WKWebView?
        private var selectionObserver: (any NSObjectProtocol)?
        /// Live while waiting for the page to report a real content size.
        private var contentSizeObservation: NSKeyValueObservation?

        init(
            progress: Binding<Double>,
            onTapLookup: ((String) -> Void)?,
            onSelectionForNote: ((String) -> Void)?
        ) {
            self._progress = progress
            self.onTapLookup = onTapLookup
            self.onSelectionForNote = onSelectionForNote
        }

        func attach(webView: WKWebView) {
            self.webView = webView
            selectionObserver = NotificationCenter.default.addObserver(
                forName: .amgiReaderRequestSelection,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // Delivered on the main queue, so assumeIsolated is safe and
                // keeps fetchSelection() synchronous.
                MainActor.assumeIsolated { self?.fetchSelection() }
            }
        }

        func detach() {
            if let observer = selectionObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            selectionObserver = nil
            contentSizeObservation = nil
            webView = nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            navigationAction.request.url?.scheme?.lowercased() == "about" ? .allow : .cancel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            didFinishLoad = true
            applyPendingInitialProgressIfLoaded()
        }

        /// Restore prior scroll position once the page reports a real
        /// content size; without this the scrollView height is still
        /// the initial frame size and our offset would be clamped.
        /// One-shot per HTML load — the flag stops later view updates
        /// from yanking the user back to the saved position.
        func applyPendingInitialProgressIfLoaded() {
            guard didFinishLoad, !didApplyInitialProgress,
                  let target = pendingInitialProgress else { return }
            didApplyInitialProgress = true
            pendingInitialProgress = nil
            guard target > 0, let scrollView = webView?.scrollView else { return }
            holdPosition(at: target, in: scrollView)
        }

        /// Scrolls to `target` and keeps it there while the page is still
        /// growing. Applying it once, on the first content size taller than
        /// the screen, landed short whenever images, web fonts or the rest
        /// of a long chapter laid out after that — and the next scroll
        /// event then recorded the wrong spot as the new position. The hold
        /// ends when the reader touches the page, or after two seconds.
        private func holdPosition(at target: Double, in scrollView: UIScrollView) {
            restoreTarget = target
            Self.applyProgress(target, to: scrollView, vertical: verticalLayout)
            // This can run inside a view update; write the binding after it.
            Task { @MainActor [weak self] in self?.progress = target }
            // `change.newValue` is unused, so nothing main-actor-isolated is
            // captured by the Sendable observation closure. contentSize is
            // mutated on the main thread, so assumeIsolated holds.
            contentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    guard let self, let target = self.restoreTarget,
                          let scrollView = self.webView?.scrollView else { return }
                    Self.applyProgress(target, to: scrollView, vertical: self.verticalLayout)
                }
            }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                self?.endHold()
            }
        }

        private func endHold() {
            restoreTarget = nil
            contentSizeObservation = nil
        }

        private static func applyProgress(_ target: Double, to scrollView: UIScrollView, vertical: Bool) {
            if vertical {
                let maxOffset = max(0, scrollView.contentSize.width - scrollView.bounds.width)
                scrollView.contentOffset.x = maxOffset * CGFloat(1 - target)
            } else {
                let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
                scrollView.contentOffset.y = maxOffset * CGFloat(target)
            }
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            endHold()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Moves made while holding a restored position aren't the
            // reader's; `progress` already says where they are.
            guard restoreTarget == nil else { return }
            let usable = verticalLayout
                ? scrollView.contentSize.width - scrollView.bounds.width
                : scrollView.contentSize.height - scrollView.bounds.height
            guard usable > 1 else {
                progress = 0
                return
            }
            let offset = verticalLayout
                ? usable - scrollView.contentOffset.x
                : scrollView.contentOffset.y
            progress = Double(min(max(offset / usable, 0), 1))
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "amgiLookup",
                  let phrase = message.body as? String,
                  !phrase.isEmpty else { return }
            onTapLookup?(phrase)
        }
    }
}

extension ChapterWebView.Coordinator {
    func fetchSelection() {
        guard let webView, let onSelectionForNote else { return }
        // window.getSelection() — current text selection in the page.
        // Empty string when nothing's selected; we just no-op then.
        webView.evaluateJavaScript("window.getSelection().toString()") { result, _ in
            guard let text = result as? String else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            onSelectionForNote(trimmed)
        }
    }
}
