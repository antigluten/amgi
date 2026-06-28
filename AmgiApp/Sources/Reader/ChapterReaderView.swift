import AmgiReader
import Sharing
import SwiftUI
import WebKit

/// Renders a chapter's HTML content in a WKWebView and tracks vertical
/// scroll progress as a 0..1 fraction of the document. The current
/// progress is captured into a binding on every scroll-end and persisted
/// when the view dismisses.
///
/// First-pass scope: read-only. No tap-to-lookup, no font/theme controls,
/// no pagination. Those layer on later via the ReaderPreferences keys
/// already declared in the Settings module.
struct ChapterReaderView: View {
    let book: ReaderBook
    let chapter: ReaderChapter
    let progress: ReaderProgressCoordinator

    @State private var scrollProgress: Double = 0
    @State private var didRestoreInitialProgress = false
    @State private var lookupQuery: String?

    @Shared(.appStorage(ReaderPreferences.Keys.fontSize))
    private var fontSize: Double = 17
    @Shared(.appStorage(ReaderPreferences.Keys.lineHeight))
    private var lineHeight: Double = 1.5
    @Shared(.appStorage(ReaderPreferences.Keys.horizontalPadding))
    private var horizontalPadding: Double = 18
    @Shared(.appStorage(ReaderPreferences.Keys.verticalPadding))
    private var verticalPadding: Double = 16
    @Shared(.appStorage(ReaderPreferences.Keys.justifyText))
    private var justifyText: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.themeMode))
    private var themeModeRaw: String = "system"
    @Shared(.appStorage(ReaderPreferences.Keys.selectedFont))
    private var selectedFontRaw: String = ReaderFontOption.defaultValue

    @Shared(.appStorage(ReaderPreferences.Keys.customTextColor))
    private var customTextColorHex: String = "#1F2A26"

    @Shared(.appStorage(ReaderPreferences.Keys.customBackgroundColor))
    private var customBackgroundColorHex: String = "#FAF7F2"
    @Shared(.appStorage(ReaderPreferences.Keys.showTitle))
    private var showTitle: Bool = true
    @Shared(.appStorage(ReaderPreferences.Keys.showPercentage))
    private var showPercentage: Bool = true
    @Shared(.appStorage(ReaderPreferences.Keys.tapLookup))
    private var tapLookup: Bool = true

    @Shared(.appStorage(ReaderPreferences.Keys.characterSpacing))
    private var characterSpacing: Double = 0
    @Shared(.appStorage(ReaderPreferences.Keys.avoidPageBreak))
    private var avoidPageBreak: Bool = true
    @Shared(.appStorage(ReaderPreferences.Keys.hideFurigana))
    private var hideFurigana: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.customHintColor))
    private var customHintColorHex: String = "#777777"

    @Shared(.appStorage(ReaderPreferences.Keys.showProgressTop))
    private var showProgressTop: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.verticalLayout))
    private var verticalLayout: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.popupDebugInfoEnabled))
    private var debugInfoEnabled: Bool = false

    @State private var pendingNoteText: String?
    @State private var lastTapPhrase: String?

    var body: some View {
        ZStack(alignment: .top) {
            ChapterWebView(
                html: wrappedHTML(chapter.content),
                initialProgress: didRestoreInitialProgress ? nil : initialProgress(),
                progress: $scrollProgress,
                onTapLookup: tapLookup
                    ? { phrase in
                        lastTapPhrase = phrase
                        lookupQuery = phrase
                    }
                    : nil,
                onSelectionForNote: { selected in pendingNoteText = selected }
            )
            if showProgressTop {
                ProgressView(value: scrollProgress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .frame(height: 2)
                    .scaleEffect(x: 1, y: 0.6, anchor: .top)
                    .ignoresSafeArea(edges: .horizontal)
            }
            if debugInfoEnabled {
                debugOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(showTitle ? chapter.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    requestSelectionForNote()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("Make note from selection")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    lookupQuery = ""
                } label: {
                    Image(systemName: "character.book.closed")
                }
                .accessibilityLabel("Look up word")
            }
            if showPercentage {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(Int(scrollProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .sheet(item: Binding(
            get: { lookupQuery.map(LookupQuery.init) },
            set: { lookupQuery = $0?.text }
        )) { wrapped in
            LookupPopupView(initialQuery: wrapped.text, languageHint: book.language) {
                lookupQuery = nil
            }
        }
        .sheet(item: Binding(
            get: { pendingNoteText.map(LookupQuery.init) },
            set: { pendingNoteText = $0?.text }
        )) { wrapped in
            // Reuse the lookup popup with the selection prefilled — the
            // popup's "+" already drives note creation through the user's
            // saved note template, so we don't need a parallel codepath.
            LookupPopupView(initialQuery: wrapped.text, languageHint: book.language) {
                pendingNoteText = nil
            }
        }
        .onAppear {
            didRestoreInitialProgress = false
        }
        .onDisappear {
            // Persist whatever the user reached. Save unconditionally —
            // even 0% writes are cheap and keep the chapterID stable so
            // the bookshelf "Resume" hint stays accurate. The coordinator
            // also fires-and-forgets a sync write to the Anki collection.
            progress.save(bookID: book.id, chapterID: chapter.id, progress: scrollProgress)
        }
    }

    private func initialProgress() -> Double? {
        guard let saved = progress.resolved(bookID: book.id),
              saved.chapterID == chapter.id else { return nil }
        return saved.progress
    }

    /// Bottom-left HUD shown only when `popupDebugInfoEnabled` is on.
    /// Useful when triaging tap-lookup misfires or font/layout issues
    /// without spinning up a debug build. Hit-testing is disabled at the
    /// call site so the overlay never swallows reader taps.
    private var debugOverlay: some View {
        let font = ReaderFontOption.resolved(selectedFontRaw)
        let latin = prefersLatinWordLayout(chapter.content)
        let layout = verticalLayout ? "vertical" : (latin ? "latin" : "cjk")
        let phrase = (lastTapPhrase ?? "—").prefix(40)
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(Int(scrollProgress * 100))% · font: \(font.title)")
            Text("layout: \(layout) · lang: \(book.language ?? "?")")
            Text("last tap: \(phrase)")
        }
        .font(.system(size: 10, design: .monospaced))
        .padding(6)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
        .foregroundStyle(.white)
    }

    /// Toolbar "+" handler: ask the WebView for the user's current
    /// selection. The WebView responds via the `onSelectionForNote`
    /// callback, which seeds `pendingNoteText` and triggers the sheet.
    private func requestSelectionForNote() {
        NotificationCenter.default.post(
            name: .amgiReaderRequestSelection,
            object: nil
        )
    }

    /// Decides whether `book.language` (or, as a fallback, the chapter
    /// content) is Latin-script-dominant. Drives `overflow-wrap` and
    /// `hyphens` rules — Latin text wraps on word boundaries and hyphenates,
    /// CJK wraps anywhere.
    private func prefersLatinWordLayout(_ content: String) -> Bool {
        if let hint = book.language?.lowercased() {
            if hint.hasPrefix("en") || hint.hasPrefix("de") || hint.hasPrefix("fr") ||
               hint.hasPrefix("es") || hint.hasPrefix("it") || hint.hasPrefix("pt") ||
               hint.hasPrefix("ru") || hint == "eng" {
                return true
            }
            if hint.hasPrefix("ja") || hint.hasPrefix("ko") || hint.hasPrefix("zh") ||
               hint == "jpn" || hint == "kor" || hint == "chi" {
                return false
            }
        }
        let plain = content
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&[A-Za-z0-9#]+;", with: " ", options: .regularExpression)
        let latin = plain.unicodeScalars.lazy.filter {
            CharacterSet.letters.contains($0) && $0.value < 128
        }.count
        let cjk = plain.unicodeScalars.lazy.filter {
            (0x3040...0x30FF).contains(Int($0.value)) ||  // Japanese kana
            (0x3400...0x9FFF).contains(Int($0.value)) ||  // CJK ideographs
            (0xAC00...0xD7AF).contains(Int($0.value))     // Hangul
        }.count
        return latin >= 40 && latin > cjk * 2
    }

    /// Wrap the raw note HTML in a tiny shell that gives us a readable
    /// default style and a known body width. Without a viewport meta
    /// tag, WKWebView can pick wildly different scales depending on the
    /// content and progress math gets noisy.
    ///
    /// CSS pulls in user prefs: font size, line height, padding, justify,
    /// theme. Theme `system` defers to the OS via prefers-color-scheme;
    /// fixed modes hardcode foreground/background. Sepia matches Anki
    /// desktop's reader-tone (#f4ecd8 / #5b4636).
    private func wrappedHTML(_ content: String) -> String {
        let mode = ReaderThemeMode(rawValue: themeModeRaw) ?? .system
        let theme = themeCSS(for: mode)
        let fontFamily = ReaderFontOption.resolved(selectedFontRaw).cssFontFamily
        let letterSpacingEm = String(format: "%.3f", characterSpacing / 100)
        let pageBreakRule = avoidPageBreak
            ? "p { break-inside: avoid; -webkit-column-break-inside: avoid; }"
            : ""
        let hintColor = ReaderThemeColor.cssHex(customHintColorHex, default: "#777777")
        let rubyRule = hideFurigana
            ? "ruby rt { display: none; }"
            : "ruby rt { color: \(hintColor); font-size: 0.55em; }"

        // Latin-dominant text wants word-boundary wrapping + hyphenation;
        // CJK wants `overflow-wrap: anywhere`. Vertical mode ignores
        // alignment (`text-align: start` is the only sensible value).
        let latinLayout = prefersLatinWordLayout(content)
        let wrappingRule = latinLayout
            ? "overflow-wrap: break-word; word-break: normal;"
            : "overflow-wrap: anywhere;"
        let hyphenRule = latinLayout ? "hyphens: auto; -webkit-hyphens: auto;" : ""
        let alignment = verticalLayout
            ? "start"
            : (justifyText && !latinLayout ? "justify" : (justifyText ? "justify" : "left"))
        let writingMode = verticalLayout ? "vertical-rl" : "horizontal-tb"
        let bodyWidthRule = verticalLayout
            ? "width: max-content; min-width: 100%;"
            : "max-width: 100%;"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
        <style>
        :root { color-scheme: light dark; }
        html, body {
          margin: 0;
          -webkit-text-size-adjust: 100%;
          text-size-adjust: 100%;
          \(wrappingRule)
        }
        body {
          font-family: \(fontFamily);
          font-size: \(Int(fontSize))px;
          line-height: \(String(format: "%.2f", lineHeight));
          letter-spacing: \(letterSpacingEm)em;
          padding: \(Int(verticalPadding))px \(Int(horizontalPadding))px \(Int(verticalPadding) + 48)px \(Int(horizontalPadding))px;
          text-align: \(alignment);
          writing-mode: \(writingMode);
          text-orientation: mixed;
          \(bodyWidthRule)
          \(hyphenRule)
          \(theme)
        }
        p { margin: 0 0 1em 0; }
        \(pageBreakRule)
        \(rubyRule)
        ::highlight(amgi-reader-selection) {
          background-color: rgba(160, 160, 160, 0.4);
          color: inherit;
        }
        img { max-width: 100%; height: auto; }
        </style>
        </head>
        <body>\(content)</body>
        </html>
        """
    }

    /// CSS palette per theme mode. `system` defers to the OS via the
    /// `-apple-system-*` semantic colors; `eyeCare` is a low-contrast
    /// dark-on-cream palette tuned for long sessions; `sepia` matches
    /// Anki desktop; `custom` stays system until the user wires up the
    /// custom-color preference UI in a follow-up chunk.
    private func themeCSS(for mode: ReaderThemeMode) -> String {
        switch mode {
        case .system:
            return "color: -apple-system-label; background: -apple-system-systemBackground;"
        case .custom:
            let text = ReaderThemeColor.cssHex(customTextColorHex, default: "#1F2A26")
            let bg = ReaderThemeColor.cssHex(customBackgroundColorHex, default: "#FAF7F2")
            return "color: \(text); background: \(bg);"
        case .eyeCare:
            return "color: #1f2a26; background: #e8f0e3;"
        case .sepia:
            return "color: #5b4636; background: #f4ecd8;"
        }
    }
}

extension Notification.Name {
    /// Toolbar → WebView ping that asks for the user's current text
    /// selection. The coordinator answers via `onSelectionForNote`.
    static let amgiReaderRequestSelection = Notification.Name("amgiReaderRequestSelection")
}

/// Wrapper so an empty-string query is still presentable via .sheet(item:);
/// `.sheet(item:)` requires `Identifiable` and treats nil as "dismissed".
private struct LookupQuery: Identifiable {
    let id = UUID()
    let text: String
}

private struct ChapterWebView: UIViewRepresentable {
    let html: String
    /// 0..1 fraction to scroll to once the page finishes loading. Read once
    /// per appearance — set to nil after the initial restore.
    let initialProgress: Double?
    @Binding var progress: Double
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
        if context.coordinator.loadedHTML != html {
            context.coordinator.loadedHTML = html
            webView.loadHTMLString(html, baseURL: nil)
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
        @Binding var progress: Double
        let onTapLookup: ((String) -> Void)?
        let onSelectionForNote: ((String) -> Void)?
        private weak var webView: WKWebView?
        private var selectionObserver: NSObjectProtocol?

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
                self?.fetchSelection()
            }
        }

        func detach() {
            if let observer = selectionObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            selectionObserver = nil
            webView = nil
        }

        private func fetchSelection() {
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

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Restore prior scroll position once the page reports a real
            // content size; without this the scrollView height is still
            // the initial frame size and our offset would be clamped.
            if let target = pendingInitialProgress, target > 0 {
                let scrollView = webView.scrollView
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
                    scrollView.contentOffset.y = maxOffset * CGFloat(target)
                }
            }
            pendingInitialProgress = nil
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let usable = scrollView.contentSize.height - scrollView.bounds.height
            guard usable > 1 else {
                progress = 0
                return
            }
            let fraction = min(max(scrollView.contentOffset.y / usable, 0), 1)
            progress = Double(fraction)
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
