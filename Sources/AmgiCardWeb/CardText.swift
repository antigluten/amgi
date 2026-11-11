//
//  CardText.swift
//  AmgiCardWeb
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import Foundation

/// Shared parsing for Anki's card wire format.
///
/// The `[sound:…]` marker and "HTML → plain text" were each reimplemented
/// several times across the app in mutually inequivalent forms — the watch's
/// stripper was the only one that removed `<style>` blocks, so the same note
/// rendered differently on the watch than in the native iOS card renderer,
/// and the watch's sound pattern was case-insensitive where the others were
/// not, so audio extraction differed by surface.
///
/// `AmgiCardWeb` is Foundation-only and already linked by every consumer,
/// including the watch, so this adds no dependency edges.
public enum CardText {
    /// Anki's audio marker. Case-insensitive: real collections contain
    /// `[Sound:…]`, and the watch already matched it that way.
    public static let soundMarkerPattern = #"(?i)\[sound:([^\]]+)\]"#

    private static let soundRegex = try? NSRegularExpression(pattern: soundMarkerPattern)
    private static let styleRegex = try? NSRegularExpression(
        pattern: #"<style[^>]*>.*?</style>"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )
    private static let scriptRegex = try? NSRegularExpression(
        pattern: #"<script[^>]*>.*?</script>"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )
    private static let tagRegex = try? NSRegularExpression(pattern: #"<[^>]+>"#)
    private static let blankLineRegex = try? NSRegularExpression(pattern: #"\n\s*\n"#)

    /// Filenames referenced by `[sound:…]` markers, in order.
    public static func soundFilenames(in html: String) -> [String] {
        guard let soundRegex else { return [] }
        let ns = html as NSString
        return soundRegex
            .matches(in: html, range: NSRange(location: 0, length: ns.length))
            .compactMap { match in
                guard match.numberOfRanges > 1 else { return nil }
                return ns.substring(with: match.range(at: 1))
            }
    }

    /// Readable plain text for a card side: drops `<style>`/`<script>`
    /// blocks and their contents, then all remaining tags and audio markers,
    /// then collapses blank runs and decodes the handful of entities Anki
    /// notes actually carry.
    public static func plainText(_ html: String) -> String {
        var out = html
        for regex in [styleRegex, scriptRegex, tagRegex, soundRegex] {
            guard let regex else { continue }
            out = regex.stringByReplacingMatches(
                in: out,
                range: NSRange(location: 0, length: (out as NSString).length),
                withTemplate: ""
            )
        }
        out = decodeEntities(out)
        if let blankLineRegex {
            out = blankLineRegex.stringByReplacingMatches(
                in: out,
                range: NSRange(location: 0, length: (out as NSString).length),
                withTemplate: "\n"
            )
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let ttsBreakRegex = try? NSRegularExpression(
        pattern: #"</?(?:br|address|article|aside|blockquote|canvas|dd|div|dl|dt|fieldset|figcaption|figure|footer|form|h[1-6]|header|hr|li|main|nav|noscript|ol|output|p|pre|section|table|tfoot|ul|video)(?:\s[^>]*)?/?>"#,
        options: .caseInsensitive
    )
    private static let commentRegex = try? NSRegularExpression(
        pattern: #"<!--.*?-->"#,
        options: .dotMatchesLineSeparators
    )
    private static let entityRegex = try? NSRegularExpression(pattern: #"&(#[xX][0-9a-fA-F]+|#[0-9]+|[A-Za-z][A-Za-z0-9]*);"#)
    private static let latin1EntityNames = """
        nbsp iexcl cent pound curren yen brvbar sect uml copy ordf laquo not shy reg macr \
        deg plusmn sup2 sup3 acute micro para middot cedil sup1 ordm raquo frac14 frac12 frac34 iquest \
        Agrave Aacute Acirc Atilde Auml Aring AElig Ccedil Egrave Eacute Ecirc Euml \
        Igrave Iacute Icirc Iuml ETH Ntilde Ograve Oacute Ocirc Otilde Ouml times \
        Oslash Ugrave Uacute Ucirc Uuml Yacute THORN szlig \
        agrave aacute acirc atilde auml aring aelig ccedil egrave eacute ecirc euml \
        igrave iacute icirc iuml eth ntilde ograve oacute ocirc otilde ouml divide \
        oslash ugrave uacute ucirc uuml yacute thorn yuml
        """.split(separator: " ")
    private static let namedEntities: [String: String] = {
        var table = [
        "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "amp": "&",
        "hellip": "\u{2026}", "mdash": "\u{2014}", "ndash": "\u{2013}",
        "lsquo": "\u{2018}", "rsquo": "\u{2019}", "ldquo": "\u{201C}", "rdquo": "\u{201D}",
        "bull": "\u{2022}", "trade": "\u{2122}", "euro": "\u{20AC}",
        "rarr": "\u{2192}", "larr": "\u{2190}", "uarr": "\u{2191}", "darr": "\u{2193}",
        ]
        for (offset, name) in latin1EntityNames.enumerated() {
            table[String(name)] = offset == 0 ? " " : String(Unicode.Scalar(UInt8(0xA0 + offset)))
        }
        return table
    }()

    /// Text for the speech synthesizer. Follows upstream `strip_html_for_tts`:
    /// block-level tags become a space first so `猫<br>犬` isn't read as one
    /// word, then markup is stripped and entities decoded. Two deliberate
    /// differences, so don't "fix" them back: break tags with attributes or
    /// self-closing (`<br/>`, `<div class="x">`) count as breaks, and an
    /// unknown entity is left as written instead of abandoning all decoding.
    /// Named entities cover the common set plus the HTML4 Latin-1 block;
    /// numeric ones below U+0020 (except tab, LF, CR) are left undecoded.
    public static func plainTextForTTS(_ html: String) -> String {
        var out = html
        if let ttsBreakRegex {
            out = ttsBreakRegex.stringByReplacingMatches(
                in: out,
                range: NSRange(location: 0, length: (out as NSString).length),
                withTemplate: " "
            )
        }
        for regex in [commentRegex, styleRegex, scriptRegex, tagRegex] {
            guard let regex else { continue }
            out = regex.stringByReplacingMatches(
                in: out,
                range: NSRange(location: 0, length: (out as NSString).length),
                withTemplate: ""
            )
        }
        return decodeAllEntities(out).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeAllEntities(_ text: String) -> String {
        guard let entityRegex, text.contains("&") else { return text }
        let ns = text as NSString
        var out = ""
        var last = 0
        for match in entityRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let name = ns.substring(with: match.range(at: 1))
            var decoded: String?
            if name.hasPrefix("#") {
                let digits = name.dropFirst()
                let value = digits.first == "x" || digits.first == "X"
                    ? UInt32(digits.dropFirst(), radix: 16)
                    : UInt32(digits)
                decoded = value.flatMap { Unicode.Scalar($0) }
                    .flatMap { ($0.value < 0x20 && ![9, 10, 13].contains($0.value)) || (0x7F...0x9F).contains($0.value) ? nil : $0 }
                    .map { $0 == "\u{A0}" ? " " : String($0) }
            } else {
                decoded = namedEntities[name]
            }
            out += decoded ?? ns.substring(with: match.range)
            last = match.range.location + match.range.length
        }
        return out + ns.substring(from: last)
    }

    private static func decodeEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            // Ampersand last, so a decoded entity can't be re-decoded.
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
