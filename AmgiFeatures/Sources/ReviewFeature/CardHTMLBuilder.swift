//
//  CardHTMLBuilder.swift
//  ReviewFeature
//
//  Created by Vladimir Gusev on 27.03.2026.
//

import AppCore
import OSLog
import SwiftUI
import WebKit
import UIKit
import AVFoundation
import AmgiCardWeb

extension CardWebView {
    /// Builds the static HTML frame page (no card content). Card HTML is injected
    /// later via evaluateJavaScript (_showQuestion/_showAnswer) so that arbitrary
    /// HTML never lives inside a <script> literal in the page source.
    static func buildFrameHTML(
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
    static func showCardScript(
        processedHTML: String,
        prefetchHTML: String?,
        cardCSS: String,
        isAnswerSide: Bool,
        lookupPopupEnabled: Bool,
        dictionaryScanLength: Int,
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
            return applyCSS + "_showAnswer(\(htmlLit),\(jsStringLiteral(bodyClass)),\(autoplay),\(jsStringLiteral(replayMode)),\(alignTopStr),\(bodyPaddingBottom),\(cardPaddingBottom),\(lookupEnabled),\(dictionaryScanLength)" + ");"
        } else {
            let prefetchLit = jsStringLiteral(prefetchHTML ?? "")
            return applyCSS + "_showQuestion(\(htmlLit),\(prefetchLit),\(jsStringLiteral(bodyClass)),\(autoplay),\(jsStringLiteral(replayMode)),\(alignTopStr),\(bodyPaddingBottom),\(cardPaddingBottom),\(lookupEnabled),\(dictionaryScanLength)" + ");"
        }
    }

    // Compiled once instead of per call. These are fixed patterns, and
    // `NSRegularExpression(pattern:)` parses and compiles the pattern every
    // time — three of those ran on each card render.
    private static let soundTagRegex = try? NSRegularExpression(
        pattern: #"\[sound:([^\]]+)\]"#, options: []
    )
    private static let ttsTagRegex = try? NSRegularExpression(
        pattern: #"\[anki:tts([^\]]*)\](.*?)\[/anki:tts\]"#,
        options: [.dotMatchesLineSeparators, .caseInsensitive]
    )
    private static let scriptTagRegex = try? NSRegularExpression(
        pattern: #"<script\b([^>]*)>"#,
        options: [.caseInsensitive]
    )

    /// Converts Anki `[sound:filename.ext]` markers to a hidden `<audio>` + styled play button.
    static func expandSoundTags(
        _ html: String,
        isDarkMode: Bool,
        showReplayButtons: Bool
    ) -> String {
        // Pattern: [sound:anything_without_closing_bracket]
        guard let regex = soundTagRegex else { return html }
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

    static func expandTTSTags(
        in html: String,
        isDarkMode: Bool,
        showReplayButtons: Bool
    ) -> String {
        guard let regex = ttsTagRegex else { return html }

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

    static func deferCardScripts(in html: String) -> String {
        guard let regex = scriptTagRegex else { return html }

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

    static func parseTTSAttributes(_ raw: String) -> [String: String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"([A-Za-z_]+)=([^\s\]]+)"#,
            options: []
        ) else { return [:] }

        let range = NSRange(raw.startIndex..., in: raw)
        let matches = regex.matches(in: raw, range: range)
        var result = [String: String](minimumCapacity: matches.count)
        for match in matches {
            guard let keyRange = Range(match.range(at: 1), in: raw),
                  let valueRange = Range(match.range(at: 2), in: raw) else { continue }
            result[String(raw[keyRange]).lowercased()] = String(raw[valueRange])
        }
        return result
    }

    static func htmlAttributeEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Memoized because the rendered bytes depend only on
    /// (systemName, isDarkMode) — at most a handful of distinct results for
    /// the whole app — yet this ran a UIGraphicsImageRenderer pass plus a
    /// PNG encode plus a base64 encode once per `[sound:]` and TTS tag, per
    /// card, synchronously inside the SwiftUI update pass.
    private static var iconHTMLCache: [String: String] = [:]

    static func audioButtonIconHTML(systemName: String, alt: String, isDarkMode: Bool) -> String {
        let cacheKey = "\(systemName)|\(alt)|\(isDarkMode)"
        if let cached = iconHTMLCache[cacheKey] { return cached }
        let html = makeAudioButtonIconHTML(systemName: systemName, alt: alt, isDarkMode: isDarkMode)
        iconHTMLCache[cacheKey] = html
        return html
    }

    private static func makeAudioButtonIconHTML(systemName: String, alt: String, isDarkMode: Bool) -> String {
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

    static func jsStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            // JavaScript treats U+2028 and U+2029 as line terminators in
            // some contexts; escaping them costs nothing and removes the
            // question entirely.
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
            // Escape </script> so it doesn't prematurely close the enclosing <script> block
            .replacingOccurrences(of: "</script>", with: "<\\/script>", options: .caseInsensitive)
        return "'\(escaped)'"
    }

    static func bodyClasses(cardOrdinal: UInt32, isDarkMode: Bool) -> String {
        var classes = ["card", "card\(Int(cardOrdinal) + 1)"]
        if isDarkMode {
            classes.append("nightMode")
            classes.append("night_mode")
        }
        return classes.joined(separator: " ")
    }

    static func htmlClasses(isDarkMode: Bool) -> String {
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
}
