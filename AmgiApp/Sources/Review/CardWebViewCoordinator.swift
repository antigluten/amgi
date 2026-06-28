import Foundation
import WebKit
import UIKit
import SwiftUI
import AVFoundation
import SafariServices
import AmgiCardWeb

// MARK: - CardWebViewCoordinator

/// WKNavigationDelegate + WKScriptMessageHandler + AVSpeechSynthesizerDelegate
/// for CardWebView.  Lifted from the DreamAfar fork (AnkiApp/Sources/Review/CardWebView.swift
/// — nested `Coordinator` class, lines ~1757-2053) and promoted to a top-level type.
///
/// The coordinator is responsible for:
///  - Receiving the 7 JS bridge messages (amgi* names)
///  - Calling back to the SwiftUI layer via stored closures
///  - AVSpeechSynthesizer integration for TTS
///  - Frame-load lifecycle so per-card evaluateJavaScript runs at the right moment
@MainActor
final class CardWebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, AVSpeechSynthesizerDelegate {

    // MARK: State tracked across updates

    var lastPageSignature: String?
    var lastContentSignature: String?
    var lastReplayRequestID: Int = 0
    var lastStopAudioRequestID: Int = 0
    var lastTypedAnswerRequestID: Int = 0
    var isPageLoaded = false
    var pendingUpdateScript: String?
    var openLinksExternally: Bool = true
    weak var currentWebView: WKWebView?

    // MARK: Callbacks (injected by makeCoordinator)

    let onTypedAnswerSubmitted: ((String?) -> Void)?
    private let onAudioStateChange: ((Bool) -> Void)?
    private let onCardBackgroundColorChange: ((UIColor, Bool) -> Void)?
    private let onLookupRequested: ((String?, String?, CGPoint) -> Void)?

    // MARK: Private state

    private var lastThemePayload: String?
    private let speechSynthesizer = AVSpeechSynthesizer()

    // MARK: Init

    init(
        onTypedAnswerSubmitted: ((String?) -> Void)? = nil,
        onAudioStateChange: ((Bool) -> Void)? = nil,
        onCardBackgroundColorChange: ((UIColor, Bool) -> Void)? = nil,
        onLookupRequested: ((String?, String?, CGPoint) -> Void)? = nil
    ) {
        self.onTypedAnswerSubmitted = onTypedAnswerSubmitted
        self.onAudioStateChange = onAudioStateChange
        self.onCardBackgroundColorChange = onCardBackgroundColorChange
        self.onLookupRequested = onLookupRequested
        super.init()
        speechSynthesizer.delegate = self
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "amgiAudioState" {
            if let isPlaying = message.body as? Bool {
                onAudioStateChange?(isPlaying)
            } else if let number = message.body as? NSNumber {
                onAudioStateChange?(number.boolValue)
            }
            return
        }

        if message.name == "amgiStopTts" {
            stopTTS()
            return
        }

        if message.name == "amgiSpeakTts" {
            speakTTS(from: message.body)
            return
        }

        if message.name == "amgiSubmitTypedAnswer" {
            if let string = message.body as? String {
                onTypedAnswerSubmitted?(string)
            } else if message.body is NSNull {
                onTypedAnswerSubmitted?(nil)
            } else {
                onTypedAnswerSubmitted?(nil)
            }
            return
        }

        if message.name == "amgiCardTheme" {
            guard let body = message.body as? [String: Any] else { return }
            let colorString = body["backgroundColor"] as? String ?? ""
            let isDark = (body["isDark"] as? Bool) ?? false
            let payload = colorString + "|" + String(isDark)
            guard payload != lastThemePayload else { return }
            lastThemePayload = payload
            guard let color = Self.parseCSSColor(colorString) else { return }
            onCardBackgroundColorChange?(color, isDark)
            return
        }

        if message.name == "amgiLookupText" {
            // Silently drop when no lookup callback is wired (inert behavior per Q1 resolution).
            guard let body = message.body as? [String: Any] else { return }
            let text = body["text"] as? String
            let sentence = body["sentence"] as? String
            let x = (body["x"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 0
            let y = (body["y"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 0
            onLookupRequested?(text, sentence, CGPoint(x: x, y: y))
            return
        }

        guard message.name == "amgiOpenLink" else { return }
        let href: String?
        if let string = message.body as? String {
            href = string
        } else {
            href = nil
        }

        guard let href, !href.isEmpty else { return }
        openLink(href)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.onAudioStateChange?(true)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.onAudioStateChange?(false)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.onAudioStateChange?(false)
        }
    }

    // MARK: - TTS

    func stopTTS() {
        guard speechSynthesizer.isSpeaking else { return }
        speechSynthesizer.stopSpeaking(at: .immediate)
        onAudioStateChange?(false)
    }

    private func speakTTS(from body: Any) {
        guard let payload = body as? [String: Any] else { return }
        let text = (payload["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return }

        stopTTS()

        let utterance = AVSpeechUtterance(string: text)
        let lang = ((payload["lang"] as? String) ?? "").replacingOccurrences(of: "_", with: "-")
        let preferredVoices = ((payload["voices"] as? String) ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let voice = preferredVoice(lang: lang, preferredNames: preferredVoices) {
            utterance.voice = voice
        } else if !lang.isEmpty {
            utterance.voice = AVSpeechSynthesisVoice(language: lang)
        }

        let speedMultiplier = Float((payload["speed"] as? String) ?? "") ?? 1
        let mappedRate = AVSpeechUtteranceDefaultSpeechRate * max(0.25, min(speedMultiplier, 2.0))
        utterance.rate = min(max(mappedRate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        speechSynthesizer.speak(utterance)
    }

    private func preferredVoice(lang: String, preferredNames: [String]) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()

        for preferredName in preferredNames {
            if let voice = voices.first(where: { $0.identifier.caseInsensitiveCompare(preferredName) == .orderedSame }) {
                return voice
            }
            if let voice = voices.first(where: { $0.name.caseInsensitiveCompare(preferredName) == .orderedSame }) {
                return voice
            }
        }

        guard !lang.isEmpty else { return nil }
        return voices.first(where: { $0.language.caseInsensitiveCompare(lang) == .orderedSame })
            ?? voices.first(where: { $0.language.lowercased().hasPrefix(lang.lowercased()) })
    }

    // MARK: - Link handling

    private func openLink(_ href: String) {
        let resolvedURL = URL(string: href, relativeTo: currentWebView?.url)?.absoluteURL
            ?? URL(string: href)

        guard let url = resolvedURL else { return }

        let scheme = url.scheme?.lowercased()
        let isWebLink = scheme == "http" || scheme == "https"

        if isWebLink, !openLinksExternally {
            currentWebView?.load(URLRequest(url: url))
            return
        }

        DispatchQueue.main.async {
            if url.scheme == "http" || url.scheme == "https" {
                self.presentSafariView(url: url)
            } else {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }

    private func presentSafariView(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.windows.first?.rootViewController else {
            UIApplication.shared.open(url)
            return
        }
        var topVC = root
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        let safari = SFSafariViewController(url: url)
        topVC.present(safari, animated: true)
    }

    // MARK: - WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        // Allow local card document loads and same-document anchors.
        let scheme = url.scheme?.lowercased()
        if url.isFileURL || scheme == "about" || scheme == "javascript" || scheme == CardAssetPath.scheme {
            decisionHandler(.allow)
            return
        }

        // Custom app links should always go to the system.
        let isWebLink = scheme == "http" || scheme == "https"
        if !isWebLink || openLinksExternally {
            decisionHandler(.cancel)
            DispatchQueue.main.async {
                if url.scheme == "http" || url.scheme == "https" {
                    self.presentSafariView(url: url)
                } else {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        } else {
            // Keep http/https inside WKWebView when external opening is disabled.
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isPageLoaded = true

        guard let pendingUpdateScript else { return }
        self.pendingUpdateScript = nil
        webView.evaluateJavaScript(pendingUpdateScript) { _, error in
            if let error {
                print("[CardWebView] evaluateJavaScript error: \(error)")
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[CardWebView] Navigation failed: \(error)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[CardWebView] Provisional navigation failed: \(error)")
    }

    // MARK: - CSS color parsing

    private static func parseCSSColor(_ cssColor: String) -> UIColor? {
        let trimmed = cssColor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasPrefix("#") {
            return parseHexColor(trimmed)
        }

        if trimmed.hasPrefix("rgb(") || trimmed.hasPrefix("rgba(") {
            let pattern = #"rgba?\((\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            guard let match = regex.firstMatch(in: trimmed, options: [], range: range) else { return nil }

            func component(_ idx: Int) -> CGFloat {
                guard let r = Range(match.range(at: idx), in: trimmed) else { return 0 }
                let value = Double(trimmed[r]) ?? 0
                return CGFloat(max(0, min(255, value)) / 255.0)
            }

            var alpha: CGFloat = 1
            if match.range(at: 4).location != NSNotFound,
               let r = Range(match.range(at: 4), in: trimmed) {
                let value = Double(trimmed[r]) ?? 1
                alpha = CGFloat(max(0, min(1, value)))
            }

            return UIColor(red: component(1), green: component(2), blue: component(3), alpha: alpha)
        }

        if trimmed == "transparent" {
            return UIColor.clear
        }

        return nil
    }

    private static func parseHexColor(_ hex: String) -> UIColor? {
        let value = String(hex.dropFirst())
        let chars = Array(value)
        func hexByte(_ a: Character, _ b: Character) -> UInt8 {
            UInt8(String([a, b]), radix: 16) ?? 0
        }

        switch chars.count {
        case 3:
            let r = hexByte(chars[0], chars[0])
            let g = hexByte(chars[1], chars[1])
            let b = hexByte(chars[2], chars[2])
            return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
        case 6:
            let r = hexByte(chars[0], chars[1])
            let g = hexByte(chars[2], chars[3])
            let b = hexByte(chars[4], chars[5])
            return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
        case 8:
            let r = hexByte(chars[0], chars[1])
            let g = hexByte(chars[2], chars[3])
            let b = hexByte(chars[4], chars[5])
            let a = hexByte(chars[6], chars[7])
            return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
        default:
            return nil
        }
    }
}
