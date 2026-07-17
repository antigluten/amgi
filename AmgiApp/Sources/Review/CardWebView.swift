import SwiftUI
import WebKit
import UIKit
import AVFoundation
import AmgiCardWeb

struct CardWebView: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

    let html: String
    let cardCSS: String
    let autoplayEnabled: Bool
    let isAnswerSide: Bool
    let cardOrdinal: UInt32
    let replayRequestID: Int
    let stopAudioRequestID: Int
    let typedAnswerRequestID: Int
    let replayMode: CardWebViewReplayMode
    let showInlineAudioReplayButtons: Bool
    let openLinksExternally: Bool
    let lookupPopupEnabled: Bool
    let prefetchHTML: String?
    let contentAlignment: CardWebViewContentAlignment
    let bottomContentInset: CGFloat
    let onTypedAnswerSubmitted: ((String?) -> Void)?
    let onAudioStateChange: ((Bool) -> Void)?
    let onCardBackgroundColorChange: ((UIColor, Bool) -> Void)?
    let onLookupRequested: ((String?, String?, CGPoint) -> Void)?

    init(
        html: String,
        cardCSS: String = "",
        autoplayEnabled: Bool = true,
        isAnswerSide: Bool = false,
        cardOrdinal: UInt32 = 0,
        replayRequestID: Int = 0,
        stopAudioRequestID: Int = 0,
        typedAnswerRequestID: Int = 0,
        replayMode: CardWebViewReplayMode = .question,
        showInlineAudioReplayButtons: Bool = true,
        openLinksExternally: Bool = true,
        lookupPopupEnabled: Bool = false,
        prefetchHTML: String? = nil,
        contentAlignment: CardWebViewContentAlignment = .center,
        bottomContentInset: CGFloat = 0,
        onTypedAnswerSubmitted: ((String?) -> Void)? = nil,
        onAudioStateChange: ((Bool) -> Void)? = nil,
        onCardBackgroundColorChange: ((UIColor, Bool) -> Void)? = nil,
        onLookupRequested: ((String?, String?, CGPoint) -> Void)? = nil
    ) {
        self.html = html
        self.cardCSS = cardCSS
        self.autoplayEnabled = autoplayEnabled
        self.isAnswerSide = isAnswerSide
        self.cardOrdinal = cardOrdinal
        self.replayRequestID = replayRequestID
        self.stopAudioRequestID = stopAudioRequestID
        self.typedAnswerRequestID = typedAnswerRequestID
        self.replayMode = replayMode
        self.showInlineAudioReplayButtons = showInlineAudioReplayButtons
        self.openLinksExternally = openLinksExternally
        self.lookupPopupEnabled = lookupPopupEnabled
        self.prefetchHTML = prefetchHTML
        self.contentAlignment = contentAlignment
        self.bottomContentInset = bottomContentInset
        self.onTypedAnswerSubmitted = onTypedAnswerSubmitted
        self.onAudioStateChange = onAudioStateChange
        self.onCardBackgroundColorChange = onCardBackgroundColorChange
        self.onLookupRequested = onLookupRequested
    }

    func makeCoordinator() -> CardWebViewCoordinator {
        CardWebViewCoordinator(
            onTypedAnswerSubmitted: onTypedAnswerSubmitted,
            onAudioStateChange: onAudioStateChange,
            onCardBackgroundColorChange: onCardBackgroundColorChange,
            onLookupRequested: onLookupRequested
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.setURLSchemeHandler(CardAssetScheme(), forURLScheme: CardAssetPath.scheme)
        config.userContentController.add(context.coordinator, name: "amgiAudioState")
        config.userContentController.add(context.coordinator, name: "amgiOpenLink")
        config.userContentController.add(context.coordinator, name: "amgiSpeakTts")
        config.userContentController.add(context.coordinator, name: "amgiStopTts")
        config.userContentController.add(context.coordinator, name: "amgiSubmitTypedAnswer")
        config.userContentController.add(context.coordinator, name: "amgiCardTheme")
        config.userContentController.add(context.coordinator, name: "amgiLookupText")

        // Tap-to-lookup. Mirrors ChapterWebView's handler: skip when
        // there's an active selection, walk text nodes from the tap
        // caret for ~32 chars, post to native. Only injected when the
        // host wired `onLookupRequested` so cards still behave normally
        // when lookup is off.
        if onLookupRequested != nil {
            config.userContentController.addUserScript(WKUserScript(
                source: Self.tapLookupBootstrapJS,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            ))
        }

        // Enable media playback without user interaction
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: CardWebViewCoordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiAudioState")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiOpenLink")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiSpeakTts")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiStopTts")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiSubmitTypedAnswer")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiCardTheme")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiLookupText")
        coordinator.stopTTS()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Convert Anki [sound:filename.mp3] tags to <audio> HTML elements.
        // The Rust renderer keeps these tags literal; the client must expand them.
        let isDarkMode = colorScheme == .dark
        let processedHTML = Self.deferCardScripts(in:
            Self.expandTTSTags(
                in: Self.expandSoundTags(
                    html,
                    isDarkMode: isDarkMode,
                    showReplayButtons: showInlineAudioReplayButtons
                ),
                isDarkMode: isDarkMode,
                showReplayButtons: showInlineAudioReplayButtons
            )
        )
        let hasTypedAnswerInput = !isAnswerSide && processedHTML.contains("id=\"typeans\"")
        let bodyPaddingBottom = hasTypedAnswerInput ? 148 : 16
        let cardPaddingBottom = hasTypedAnswerInput ? 96 : 0
        let alignTop = hasTypedAnswerInput || contentAlignment == .top
        let bodyClass = Self.bodyClasses(cardOrdinal: cardOrdinal, isDarkMode: isDarkMode)
        let pageSignature = "\(isDarkMode)"
        let cssSignature = "\(cardCSS.hashValue)"
        let contentSignature = "\(autoplayEnabled)|\(isAnswerSide)|\(lookupPopupEnabled)|\(replayMode.rawValue)|\(cardOrdinal)|\(alignTop)|\(bodyPaddingBottom)|\(cardPaddingBottom)|\(cssSignature)|\(processedHTML.hashValue)|\(prefetchHTML?.hashValue ?? 0)"
        context.coordinator.openLinksExternally = openLinksExternally
        context.coordinator.currentWebView = webView
        webView.overrideUserInterfaceStyle = isDarkMode ? .dark : .light

        // Build the JS call that shows the card – passed via evaluateJavaScript so
        // HTML content never lives inside a <script> literal in the page source.
        let showCardScript = Self.showCardScript(
            processedHTML: processedHTML,
            prefetchHTML: prefetchHTML,
            cardCSS: cardCSS,
            isAnswerSide: isAnswerSide,
            lookupPopupEnabled: lookupPopupEnabled,
            bodyClass: bodyClass,
            autoplayEnabled: autoplayEnabled,
            replayMode: replayMode.rawValue,
            alignTop: alignTop,
            bodyPaddingBottom: bodyPaddingBottom,
            cardPaddingBottom: cardPaddingBottom
        )
        context.coordinator.stopTTS()

        if context.coordinator.lastPageSignature != pageSignature {
            context.coordinator.lastPageSignature = pageSignature
            context.coordinator.lastContentSignature = contentSignature
            context.coordinator.isPageLoaded = false
            context.coordinator.pendingUpdateScript = nil
            let htmlClass = Self.htmlClasses(isDarkMode: isDarkMode)
            let playIconHTML = Self.audioButtonIconHTML(systemName: "play.circle", alt: "Play", isDarkMode: isDarkMode)
            let pauseIconHTML = Self.audioButtonIconHTML(systemName: "pause.circle", alt: "Pause", isDarkMode: isDarkMode)
            let baseTag = CardAssetPath.mediaBaseTag()
            // Stash the show-card call so we can run it once the page finishes loading.
            context.coordinator.pendingUpdateScript = showCardScript

            let styledHTML = Self.buildFrameHTML(
                htmlClass: htmlClass,
                isDarkMode: isDarkMode,
                playIconHTML: playIconHTML,
                pauseIconHTML: pauseIconHTML,
                baseTag: baseTag
            )

            // Use cardBaseURL so that MathJax, fonts, and other resources load correctly.
            // The CardAssetScheme handler processes amgi-asset:// URLs.
            webView.loadHTMLString(styledHTML, baseURL: CardAssetPath.cardBaseURL)
        } else if context.coordinator.lastContentSignature != contentSignature {
            context.coordinator.lastContentSignature = contentSignature
            if context.coordinator.isPageLoaded {
                webView.evaluateJavaScript(showCardScript, completionHandler: nil)
            } else {
                context.coordinator.pendingUpdateScript = showCardScript
            }
        }
        if replayRequestID != context.coordinator.lastReplayRequestID {
            context.coordinator.lastReplayRequestID = replayRequestID
            webView.evaluateJavaScript("window.amgiReplayAll && window.amgiReplayAll('" + replayMode.rawValue + "');", completionHandler: nil)
        }

        if stopAudioRequestID != context.coordinator.lastStopAudioRequestID {
            context.coordinator.lastStopAudioRequestID = stopAudioRequestID
            webView.evaluateJavaScript("window.amgiStopAllAudio && window.amgiStopAllAudio();", completionHandler: nil)
        }

        if typedAnswerRequestID != context.coordinator.lastTypedAnswerRequestID {
            context.coordinator.lastTypedAnswerRequestID = typedAnswerRequestID
            webView.evaluateJavaScript("window.amgiGetTypedAnswer ? window.amgiGetTypedAnswer() : null") { value, _ in
                let typedAnswer: String?
                if let string = value as? String {
                    typedAnswer = string
                } else {
                    typedAnswer = nil
                }
                context.coordinator.onTypedAnswerSubmitted?(typedAnswer)
            }
        }

        // Force bottom content inset so card content can always scroll above the floating
        // action bar. WKWebView does not reliably inherit SwiftUI safeAreaInset changes,
        // so we set it explicitly via DispatchQueue.main.async to override any WebKit-internal
        // layout pass that might run after updateUIView.
        let targetInset = bottomContentInset
        DispatchQueue.main.async {
            webView.scrollView.contentInset.bottom = targetInset
            webView.scrollView.scrollIndicatorInsets.bottom = targetInset
        }
    }

    // MARK: - Helpers

    /// Loads the frame HTML template from the bundled CardWebViewBridge.js resource.
    /// Despite the .js extension, this file is the complete HTML frame document
    /// (including <style> and <script> blocks) with runtime placeholder tokens.
    /// It is named .js because the resource was extracted under that name in Task 8.
    private static let bridgeFrameTemplate: String = {
        guard let url = Bundle.main.url(forResource: "CardWebViewBridge", withExtension: "js", subdirectory: "Review"),
              let data = try? Data(contentsOf: url),
              let str = String(data: data, encoding: .utf8) else {
            assertionFailure("CardWebViewBridge.js missing from bundle — regenerate xcodeproj")
            return ""
        }
        return str
    }()

    /// Builds the static HTML frame page (no card content). Card HTML is injected
    /// later via evaluateJavaScript (_showQuestion/_showAnswer) so that arbitrary
    /// HTML never lives inside a <script> literal in the page source.
    private static func buildFrameHTML(
        htmlClass: String,
        isDarkMode: Bool,
        playIconHTML: String,
        pauseIconHTML: String,
        baseTag: String
    ) -> String {
        let colorScheme = isDarkMode ? "dark" : "light"
        // Keep the frame background transparent in both light and dark modes.
        // The review toolbar/bottom chrome must sample the rendered card template
        // background; reintroducing a dark-only fallback here makes the wrapper
        // background win over the template color and breaks auto-match again.
        let defaultCardBackground = "transparent"
        let textColor = isDarkMode ? "#f5f5f5" : "#1a1a1a"
        let hrColor = isDarkMode ? "rgba(255,255,255,0.2)" : "rgba(0,0,0,0.2)"
        let typeBorderColor = isDarkMode ? "rgba(255,255,255,0.28)" : "rgba(0,0,0,0.22)"
        let typeBgColor = isDarkMode ? "rgba(255,255,255,0.08)" : "rgba(255,255,255,0.9)"
        let typeFocusBorder = isDarkMode ? "rgba(143,184,255,0.9)" : "rgba(0,122,255,0.9)"
        let typeFocusShadow = isDarkMode ? "rgba(143,184,255,0.18)" : "rgba(0,122,255,0.15)"
        let typeCodeBg = isDarkMode ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.05)"
        let missingMediaColor = isDarkMode ? "rgba(255,100,100,0.9)" : "rgba(200,40,40,0.8)"
        let playIconLiteral = jsStringLiteral(playIconHTML)
        let pauseIconLiteral = jsStringLiteral(pauseIconHTML)
        let mathJaxConfigScriptURL = jsStringLiteral(CardAssetPath.mathJaxConfigScriptURLString)
        let mathJaxCoreScriptURL = jsStringLiteral(CardAssetPath.mathJaxCoreScriptURLString)

        return bridgeFrameTemplate
            .replacingOccurrences(of: "__AMGI_HTML_CLASS__", with: htmlClass)
            .replacingOccurrences(of: "__AMGI_COLOR_SCHEME__", with: colorScheme)
            .replacingOccurrences(of: "__AMGI_DEFAULT_CARD_BG__", with: defaultCardBackground)
            .replacingOccurrences(of: "__AMGI_TEXT_COLOR__", with: textColor)
            .replacingOccurrences(of: "__AMGI_HR_COLOR__", with: hrColor)
            .replacingOccurrences(of: "__AMGI_TYPE_BORDER_COLOR__", with: typeBorderColor)
            .replacingOccurrences(of: "__AMGI_TYPE_BG_COLOR__", with: typeBgColor)
            .replacingOccurrences(of: "__AMGI_TYPE_FOCUS_BORDER__", with: typeFocusBorder)
            .replacingOccurrences(of: "__AMGI_TYPE_FOCUS_SHADOW__", with: typeFocusShadow)
            .replacingOccurrences(of: "__AMGI_TYPE_CODE_BG__", with: typeCodeBg)
            .replacingOccurrences(of: "__AMGI_MISSING_MEDIA_COLOR__", with: missingMediaColor)
            .replacingOccurrences(of: "__AMGI_PLAY_ICON_LITERAL__", with: playIconLiteral)
            .replacingOccurrences(of: "__AMGI_PAUSE_ICON_LITERAL__", with: pauseIconLiteral)
            .replacingOccurrences(of: "__AMGI_MATHJAX_CONFIG_URL__", with: mathJaxConfigScriptURL)
            .replacingOccurrences(of: "__AMGI_MATHJAX_CORE_URL__", with: mathJaxCoreScriptURL)
            .replacingOccurrences(of: "__AMGI_BASE_TAG__", with: baseTag)
    }

    /// Builds the evaluateJavaScript call that shows the card.
    /// HTML content is passed as JS string arguments – never embedded inside
    /// a <script> tag in the page source – eliminating </script> injection risk.
    private static func showCardScript(
        processedHTML: String,
        prefetchHTML: String?,
        cardCSS: String,
        isAnswerSide: Bool,
        lookupPopupEnabled: Bool,
        bodyClass: String,
        autoplayEnabled: Bool,
        replayMode: String,
        alignTop: Bool,
        bodyPaddingBottom: Int,
        cardPaddingBottom: Int
    ) -> String {
        let htmlLit = jsStringLiteral(processedHTML)
        let cssLit = jsStringLiteral(cardCSS)
        let autoplay = autoplayEnabled ? "true" : "false"
        let lookupEnabled = lookupPopupEnabled ? "true" : "false"
        let alignTopStr = alignTop ? "true" : "false"
        let applyCSS = "amgiSetCardCSS(\(cssLit));"

        if isAnswerSide {
            return applyCSS + "_showAnswer(\(htmlLit),\(jsStringLiteral(bodyClass)),\(autoplay),\(jsStringLiteral(replayMode)),\(alignTopStr),\(bodyPaddingBottom),\(cardPaddingBottom),\(lookupEnabled)" + ");"
        } else {
            let prefetchLit = jsStringLiteral(prefetchHTML ?? "")
            return applyCSS + "_showQuestion(\(htmlLit),\(prefetchLit),\(jsStringLiteral(bodyClass)),\(autoplay),\(jsStringLiteral(replayMode)),\(alignTopStr),\(bodyPaddingBottom),\(cardPaddingBottom),\(lookupEnabled)" + ");"
        }
    }

    /// Converts Anki `[sound:filename.ext]` markers to a hidden `<audio>` + styled play button.
    private static func expandSoundTags(
        _ html: String,
        isDarkMode: Bool,
        showReplayButtons: Bool
    ) -> String {
        // Pattern: [sound:anything_without_closing_bracket]
        guard let regex = try? NSRegularExpression(
            pattern: #"\[sound:([^\]]+)\]"#, options: []
        ) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        var result = html
        // Process in reverse order to preserve character indices
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: result),
                  let filenameRange = Range(match.range(at: 1), in: result) else { continue }
            let filename = String(result[filenameRange])
            let encoded = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
            let replacement: String
            if showReplayButtons {
                let iconHTML = audioButtonIconHTML(systemName: "play.circle", alt: "Play", isDarkMode: isDarkMode)
                replacement = "<span class=\"sound-btn\"><audio class=\"anki-sound-audio\" src=\"\(encoded)\" preload=\"auto\"></audio><a class=\"replay-button replay-btn soundLink\" href=\"#\" draggable=\"false\" onclick=\"return playSound(this)\">\(iconHTML)</a></span>"
            } else {
                replacement = "<span class=\"sound-btn\"><audio class=\"anki-sound-audio\" src=\"\(encoded)\" preload=\"auto\"></audio></span>"
            }
            result.replaceSubrange(matchRange, with: replacement)
        }
        return result
    }

    private static func expandTTSTags(
        in html: String,
        isDarkMode: Bool,
        showReplayButtons: Bool
    ) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"\[anki:tts([^\]]*)\](.*?)\[/anki:tts\]"#,
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) else { return html }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        var result = html

        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: result),
                  let attrsRange = Range(match.range(at: 1), in: result),
                  let textRange = Range(match.range(at: 2), in: result) else { continue }

            let options = parseTTSAttributes(String(result[attrsRange]))
            let spokenText = String(result[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let lang = options["lang"] ?? ""
            let voices = options["voices"] ?? ""
            let speed = options["speed"] ?? ""

            let replacement: String
            if showReplayButtons {
                let iconHTML = audioButtonIconHTML(systemName: "play.circle", alt: "Speak", isDarkMode: isDarkMode)
                replacement = "<a class=\"replay-button replay-btn tts-btn\" href=\"#\" draggable=\"false\" data-tts-text=\"\(htmlAttributeEscaped(spokenText))\" data-tts-lang=\"\(htmlAttributeEscaped(lang))\" data-tts-voices=\"\(htmlAttributeEscaped(voices))\" data-tts-speed=\"\(htmlAttributeEscaped(speed))\" onclick=\"return amgiSpeakTts(this)\">\(iconHTML)</a>"
            } else {
                replacement = ""
            }

            result.replaceSubrange(matchRange, with: replacement)
        }

        return result
    }

    private static func deferCardScripts(in html: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"<script\b([^>]*)>"#,
            options: [.caseInsensitive]
        ) else { return html }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        var result = html

        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: result),
                  let attrsRange = Range(match.range(at: 1), in: result) else { continue }

            let attrs = String(result[attrsRange])
            let withoutQuotedType = attrs.replacingOccurrences(
                of: #"\stype\s*=\s*(["']).*?\1"#,
                with: "",
                options: .regularExpression
            )
            let cleanedAttrs = withoutQuotedType.replacingOccurrences(
                of: #"\stype\s*=\s*[^\s>]+"#,
                with: "",
                options: .regularExpression
            )

            let replacement = "<script type=\"application/x-amgi-card-script\" data-amgi-card-script=\"1\"\(cleanedAttrs)>"
            result.replaceSubrange(matchRange, with: replacement)
        }

        return result
    }

    private static func parseTTSAttributes(_ raw: String) -> [String: String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"([A-Za-z_]+)=([^\s\]]+)"#,
            options: []
        ) else { return [:] }

        let range = NSRange(raw.startIndex..., in: raw)
        let matches = regex.matches(in: raw, range: range)
        var result: [String: String] = [:]
        for match in matches {
            guard let keyRange = Range(match.range(at: 1), in: raw),
                  let valueRange = Range(match.range(at: 2), in: raw) else { continue }
            result[String(raw[keyRange]).lowercased()] = String(raw[valueRange])
        }
        return result
    }

    private static func htmlAttributeEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func audioButtonIconHTML(systemName: String, alt: String, isDarkMode: Bool) -> String {
        let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular, scale: .medium)
        let tint = isDarkMode ? UIColor.white : UIColor(red: 26 / 255, green: 26 / 255, blue: 26 / 255, alpha: 1)
        guard let baseImage = UIImage(systemName: systemName, withConfiguration: configuration) else {
            return alt
        }

        let image = baseImage.withTintColor(tint, renderingMode: .alwaysOriginal)
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let rendered = renderer.image { _ in
            image.draw(at: .zero)
        }

        guard let data = rendered.pngData() else {
            return alt
        }

        return "<img class=\"amgi-inline-icon\" src=\"data:image/png;base64,\(data.base64EncodedString())\" alt=\"\(alt)\" draggable=\"false\" style=\"width:28px;height:28px;max-width:none;display:block;flex:none;\" />"
    }

    private static func jsStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            // Escape </script> so it doesn't prematurely close the enclosing <script> block
            .replacingOccurrences(of: "</script>", with: "<\\/script>", options: .caseInsensitive)
        return "'\(escaped)'"
    }

    private static func bodyClasses(cardOrdinal: UInt32, isDarkMode: Bool) -> String {
        var classes = ["card", "card\(Int(cardOrdinal) + 1)"]
        if isDarkMode {
            classes.append("nightMode")
            classes.append("night_mode")
        }
        return classes.joined(separator: " ")
    }

    private static func htmlClasses(isDarkMode: Bool) -> String {
        var classes: [String] = []

        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            classes.append("ios")
            classes.append("ipad")
            classes.append("mobile")
        case .phone:
            classes.append("ios")
            classes.append("iphone")
            classes.append("mobile")
        default:
            break
        }

        if isDarkMode {
            classes.append("nightMode")
            classes.append("night_mode")
        }

        return classes.joined(separator: " ")
    }

    /// Tap-to-lookup user script. Listens for click events at the
    /// capture phase, skips when there's an active selection (so taps
    /// that dismiss selection don't also fire a lookup), grabs ~32
    /// chars of text from the caret point, and posts to the native
    /// `amgiLookupText` handler with the phrase + tap coordinates +
    /// surrounding sentence context. Mirrors the chapter reader's
    /// gesture so reviewer + reader behave the same.
    private static let tapLookupBootstrapJS = """
    document.addEventListener('click', function(e) {
      const sel = window.getSelection();
      if (sel && sel.toString().length > 0) { return; }
      const range = document.caretRangeFromPoint(e.clientX, e.clientY);
      if (!range) { return; }
      let phrase = '';
      let node = range.startContainer;
      let offset = range.startOffset;
      while (node && phrase.length < 32) {
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
      if (phrase.length > 0) {
        window.webkit.messageHandlers.amgiLookupText.postMessage({
          text: phrase,
          sentence: '',
          x: e.clientX,
          y: e.clientY
        });
      }
    }, true);
    """
}
