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
