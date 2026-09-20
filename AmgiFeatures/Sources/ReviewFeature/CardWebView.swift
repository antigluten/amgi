//
//  CardWebView.swift
//  ReviewFeature
//
//  Created by Vladimir Gusev on 27.03.2026.
//

import AppCore
import AppShared
import OSLog
import Reader
import SwiftUI
import WebKit
import UIKit
import AVFoundation
import AmgiCardWeb


@MainActor
struct CardWebView {
    @Environment(\.colorScheme) private var colorScheme

    let html: String
    let cardCSS: String
    let autoplayEnabled: Bool
    let isAnswerSide: Bool
    let cardOrdinal: UInt32
    let replayRequestID: Int
    let stopAudioRequestID: Int
    let replayMode: CardWebViewReplayMode
    let showInlineAudioReplayButtons: Bool
    let openLinksExternally: Bool
    let lookupPopupEnabled: Bool
    let dictionaryScanLength: Int
    let lookupHighlight: LookupHighlight
    let prefetchHTML: String?
    let contentAlignment: CardWebViewContentAlignment
    let bottomContentInset: CGFloat
    let onAudioStateChange: ((Bool) -> Void)?
    let onCardBackgroundColorChange: ((Color, Bool) -> Void)?
    let onLookupRequested: ((String?, String?, CGPoint) -> Void)?
    let onShowAnswerRequested: (() -> Void)?

    init(
        html: String,
        cardCSS: String = "",
        autoplayEnabled: Bool = true,
        isAnswerSide: Bool = false,
        cardOrdinal: UInt32 = 0,
        replayRequestID: Int = 0,
        stopAudioRequestID: Int = 0,
        replayMode: CardWebViewReplayMode = .question,
        showInlineAudioReplayButtons: Bool = true,
        openLinksExternally: Bool = true,
        lookupPopupEnabled: Bool = false,
        dictionaryScanLength: Int = 16,
        lookupHighlight: LookupHighlight = LookupHighlight(),
        prefetchHTML: String? = nil,
        contentAlignment: CardWebViewContentAlignment = .center,
        bottomContentInset: CGFloat = 0,
        onAudioStateChange: ((Bool) -> Void)? = nil,
        onCardBackgroundColorChange: ((Color, Bool) -> Void)? = nil,
        onLookupRequested: ((String?, String?, CGPoint) -> Void)? = nil,
        onShowAnswerRequested: (() -> Void)? = nil
    ) {
        self.html = html
        self.cardCSS = cardCSS
        self.autoplayEnabled = autoplayEnabled
        self.isAnswerSide = isAnswerSide
        self.cardOrdinal = cardOrdinal
        self.replayRequestID = replayRequestID
        self.stopAudioRequestID = stopAudioRequestID
        self.replayMode = replayMode
        self.showInlineAudioReplayButtons = showInlineAudioReplayButtons
        self.openLinksExternally = openLinksExternally
        self.lookupPopupEnabled = lookupPopupEnabled
        self.dictionaryScanLength = dictionaryScanLength
        self.lookupHighlight = lookupHighlight
        self.prefetchHTML = prefetchHTML
        self.contentAlignment = contentAlignment
        self.bottomContentInset = bottomContentInset
        self.onAudioStateChange = onAudioStateChange
        self.onCardBackgroundColorChange = onCardBackgroundColorChange
        self.onLookupRequested = onLookupRequested
        self.onShowAnswerRequested = onShowAnswerRequested
    }

    func makeCoordinator() -> CardWebViewCoordinator {
        CardWebViewCoordinator(
            onAudioStateChange: onAudioStateChange,
            onCardBackgroundColorChange: onCardBackgroundColorChange,
            onLookupRequested: onLookupRequested,
            onShowAnswerRequested: onShowAnswerRequested
        )
    }

    func makeWebView(coordinator: CardWebViewCoordinator) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.setURLSchemeHandler(CardAssetScheme(), forURLScheme: CardAssetPath.scheme)
        config.userContentController.add(coordinator, name: "amgiAudioState")
        config.userContentController.add(coordinator, name: "amgiOpenLink")
        config.userContentController.add(coordinator, name: "amgiSpeakTts")
        config.userContentController.add(coordinator, name: "amgiStopTts")
        config.userContentController.add(coordinator, name: "amgiCardTheme")
        config.userContentController.add(coordinator, name: "amgiLookupText")
        config.userContentController.add(coordinator, name: "amgiShowAnswer")

        config.userContentController.addUserScript(WKUserScript(
            source: LookupExtractionScript.source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        // Enable media playback without user interaction
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.navigationDelegate = coordinator
        return webView
    }

    static func dismantleWebView(_ webView: WKWebView, coordinator: CardWebViewCoordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiAudioState")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiOpenLink")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiSpeakTts")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiStopTts")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiCardTheme")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiLookupText")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "amgiShowAnswer")
        coordinator.stopTTS()
    }

    func updateWebView(_ webView: WKWebView, coordinator: CardWebViewCoordinator) {
        let isDarkMode = colorScheme == .dark
        let alignTop = contentAlignment == .top

        // Both signatures are derived from the *inputs*, never from the
        // processed output. `processedHTML` costs three whole-document regex
        // passes, so hashing it to decide whether anything changed meant
        // paying that cost on every render and usually throwing it away.
        // `ReviewContent` reads a dozen `session.*` properties, so an
        // audio-state flip, an undo, or a flag tap each used to run all three.
        // `html`, `isDarkMode`, and `showInlineAudioReplayButtons` are its only
        // inputs, so they discriminate exactly as well.
        let pageSignature = "\(isDarkMode)"
        // `bottomContentInset` joins the signature because it is now carried as
        // body padding in the show-card script rather than as a scroll inset.
        let contentSignature = "\(autoplayEnabled)|\(isAnswerSide)|\(lookupPopupEnabled)|\(dictionaryScanLength)|\(replayMode.rawValue)|\(cardOrdinal)|\(alignTop)|\(showInlineAudioReplayButtons)|\(Int(bottomContentInset))|\(cardCSS.hashValue)|\(html.hashValue)|\(prefetchHTML?.hashValue ?? 0)"

        // Bookkeeping that has to track every render, expensive or not.
        coordinator.openLinksExternally = openLinksExternally
        coordinator.currentWebView = webView
        webView.overrideUserInterfaceStyle = isDarkMode ? .dark : .light

        let pageChanged = coordinator.lastPageSignature != pageSignature
        let contentChanged = coordinator.lastContentSignature != contentSignature

        if pageChanged || contentChanged {
            // Convert Anki [sound:filename.mp3] tags to <audio> HTML elements.
            // The Rust renderer keeps these tags literal; the client must expand them.
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
            let bodyPaddingBottom = 16 + Int(bottomContentInset)
            let cardPaddingBottom = 0
            let bodyClass = Self.bodyClasses(cardOrdinal: cardOrdinal, isDarkMode: isDarkMode)

            // Build the JS call that shows the card – passed via evaluateJavaScript so
            // HTML content never lives inside a <script> literal in the page source.
            let showCardScript = Self.showCardScript(
                processedHTML: processedHTML,
                prefetchHTML: prefetchHTML,
                cardCSS: cardCSS,
                isAnswerSide: isAnswerSide,
                lookupPopupEnabled: lookupPopupEnabled,
                dictionaryScanLength: dictionaryScanLength,
                bodyClass: bodyClass,
                autoplayEnabled: autoplayEnabled,
                replayMode: replayMode.rawValue,
                alignTop: alignTop,
                bodyPaddingBottom: bodyPaddingBottom,
                cardPaddingBottom: cardPaddingBottom
            )
            // Only when the card content actually changes. Unconditionally,
            // any unrelated re-render — including the audio callback writing
            // `isAudioPlaying` back onto the session — cut off speech that was
            // still playing.
            coordinator.stopTTS()

            if pageChanged {
                coordinator.lastPageSignature = pageSignature
                coordinator.lastContentSignature = contentSignature
                coordinator.isPageLoaded = false
                let htmlClass = Self.htmlClasses(isDarkMode: isDarkMode)
                let playIconHTML = Self.audioButtonIconHTML(systemName: "play.circle", alt: "Play", isDarkMode: isDarkMode)
                let pauseIconHTML = Self.audioButtonIconHTML(systemName: "pause.circle", alt: "Pause", isDarkMode: isDarkMode)
                let baseTag = CardAssetPath.mediaBaseTag()
                // Stash the show-card call so we can run it once the page finishes loading.
                coordinator.pendingUpdateScript = showCardScript

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
            } else {
                coordinator.lastContentSignature = contentSignature
                if coordinator.isPageLoaded {
                    webView.evaluateJavaScript(showCardScript) { _, error in
                        // A JS exception in _showQuestion/_showAnswer renders
                        // a blank card; dropping the error left no diagnostic.
                        if let error { Log.review.error("showCard script failed: \(error)") }
                    }
                } else {
                    coordinator.pendingUpdateScript = showCardScript
                }
            }
        }
        if replayRequestID != coordinator.lastReplayRequestID {
            coordinator.lastReplayRequestID = replayRequestID
            webView.evaluateJavaScript("window.amgiReplayAll && window.amgiReplayAll('" + replayMode.rawValue + "');") { _, error in
                if let error { Log.review.error("replayAll script failed: \(error)") }
            }
        }

        if stopAudioRequestID != coordinator.lastStopAudioRequestID {
            coordinator.lastStopAudioRequestID = stopAudioRequestID
            webView.evaluateJavaScript("window.amgiStopAllAudio && window.amgiStopAllAudio();") { _, error in
                if let error { Log.review.error("stopAllAudio script failed: \(error)") }
            }
        }

        if lookupHighlight.generation != coordinator.lastLookupHighlightGeneration {
            coordinator.lastLookupHighlightGeneration = lookupHighlight.generation
            let call = lookupHighlight.utf16Length > 0 ? "highlightMatched(\(lookupHighlight.utf16Length))" : "clearHighlight()"
            webView.evaluateJavaScript("window.amgiLookup && window.amgiLookup.\(call);") { _, error in
                if let error { Log.review.error("lookup highlight script failed: \(error)") }
            }
        }

    }

    // MARK: - Helpers

    /// Loads the frame HTML template from the bundled CardWebViewBridge.js resource.
    /// Despite the .js extension, this file is the complete HTML frame document
    /// (including <style> and <script> blocks) with runtime placeholder tokens.
    /// It is named .js because the resource was extracted under that name in Task 8.
    // Internal rather than private: the HTML builder lives in
    // CardHTMLBuilder.swift now, and `private` is file-scoped.
    static let bridgeFrameTemplate: String = {
        guard let url = Bundle.main.url(forResource: "CardWebViewBridge", withExtension: "js", subdirectory: "Review"),
              let data = try? Data(contentsOf: url),
              let str = String(data: data, encoding: .utf8) else {
            assertionFailure("CardWebViewBridge.js missing from bundle — regenerate xcodeproj")
            return ""
        }
        return str
    }()
}

// MARK: - Representable conformance

extension CardWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        makeWebView(coordinator: context.coordinator)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        updateWebView(webView, coordinator: context.coordinator)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: CardWebViewCoordinator) {
        dismantleWebView(webView, coordinator: coordinator)
    }
}
