public import Foundation

/// Structured content for the native card renderer (R11): the rendered HTML
/// of an allowlist-simple card reduced to display blocks plus extracted audio
/// file references. `CardComplexity` gates entry, so the parser only ever
/// sees tags it understands; anything unrecognized is stripped.
public struct NativeCardContent: Sendable, Equatable {
    public enum Block: Sendable, Equatable {
        case text(AttributedString)
        case image(filename: String)
        case divider
    }

    public let blocks: [Block]
    public let audioFiles: [String]

    public init(blocks: [Block], audioFiles: [String]) {
        self.blocks = blocks
        self.audioFiles = audioFiles
    }

    public static func parse(html: String) -> NativeCardContent {
        var audioFiles: [String] = []
        let withoutSound = soundRegex.replacing(in: html) { match in
            audioFiles.append(match)
            return ""
        }

        var blocks: [Block] = []
        let ns = withoutSound as NSString
        var cursor = 0

        func flushText(upTo location: Int) {
            let raw = ns.substring(with: NSRange(location: cursor, length: location - cursor))
            if let text = parseInlineText(raw) {
                blocks.append(.text(text))
            }
        }

        for match in boundaryRegex.matches(in: withoutSound, range: NSRange(location: 0, length: ns.length)) {
            flushText(upTo: match.range.location)
            cursor = match.range.location + match.range.length

            let rawTag = ns.substring(with: match.range)
            let tag = rawTag.lowercased()
            if tag.hasPrefix("<hr") {
                blocks.append(.divider)
            } else if tag.hasPrefix("<img") {
                if let src = imageSource(in: rawTag) {
                    blocks.append(.image(filename: src))
                }
            }
            // <br>, </div>, </p>, </center> are pure separators.
        }
        flushText(upTo: ns.length)

        return NativeCardContent(blocks: blocks, audioFiles: audioFiles)
    }

    // MARK: - Regexes

    private static let soundRegex = try! NSRegularExpression(pattern: #"\[sound:([^\]]+)\]"#)

    /// Block boundaries: standalone blocks (`<hr>`, `<img>`) and separators.
    private static let boundaryRegex = try! NSRegularExpression(
        pattern: #"<hr\s*/?>|<img\b[^>]*>|<br\s*/?>|</div>|</p>|</center>"#,
        options: [.caseInsensitive]
    )

    /// Inline emphasis tags handled during text-run construction.
    /// (`<u>` is allowlisted but renders plain — underline attributes need a
    /// UI framework scope this Foundation-only module doesn't import.)
    private static let inlineTagRegex = try! NSRegularExpression(
        pattern: #"</?(b|strong|i|em)\b[^>]*>"#,
        options: [.caseInsensitive]
    )

    private static let anyTagRegex = try! NSRegularExpression(pattern: #"<[^>]+>"#)

    private static func imageSource(in tag: String) -> String? {
        let regex = try! NSRegularExpression(pattern: #"src\s*=\s*["']([^"']+)["']"#)
        let ns = tag as NSString
        guard let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        return ns.substring(with: match.range(at: 1))
    }

    // MARK: - Inline text

    /// Builds an `AttributedString` from an HTML fragment: `<b>/<strong>` and
    /// `<i>/<em>` become presentation-intent runs, `<u>` underlines, all other
    /// tags are stripped, and basic entities are decoded. Returns nil when the
    /// fragment reduces to whitespace.
    private static func parseInlineText(_ fragment: String) -> AttributedString? {
        var result = AttributedString()
        var boldDepth = 0
        var italicDepth = 0

        let ns = fragment as NSString
        var cursor = 0

        func appendRun(_ raw: String) {
            let text = decodeEntities(strippingTags(raw))
            guard !text.isEmpty else { return }
            var run = AttributedString(text)
            var intent: InlinePresentationIntent = []
            if boldDepth > 0 { intent.insert(.stronglyEmphasized) }
            if italicDepth > 0 { intent.insert(.emphasized) }
            if !intent.isEmpty { run.inlinePresentationIntent = intent }
            result += run
        }

        for match in inlineTagRegex.matches(in: fragment, range: NSRange(location: 0, length: ns.length)) {
            appendRun(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            cursor = match.range.location + match.range.length

            let tag = ns.substring(with: match.range).lowercased()
            let closing = tag.hasPrefix("</")
            let delta = closing ? -1 : 1
            let name = ns.substring(with: match.range(at: 1)).lowercased()
            switch name {
            case "b", "strong": boldDepth = max(0, boldDepth + delta)
            case "i", "em": italicDepth = max(0, italicDepth + delta)
            default: break
            }
        }
        appendRun(ns.substring(from: cursor))

        let plain = String(result.characters)
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Trim leading/trailing whitespace off the attributed result.
        if let start = plain.range(of: trimmed) {
            let lower = result.index(result.startIndex, offsetByCharacters: plain.distance(from: plain.startIndex, to: start.lowerBound))
            let upper = result.index(lower, offsetByCharacters: trimmed.count)
            return AttributedString(result[lower..<upper])
        }
        return result
    }

    private static func strippingTags(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return anyTagRegex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        let entities: [(String, String)] = [
            ("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&"),
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }
}

private extension NSRegularExpression {
    /// Replaces every match with `transform(firstCaptureGroup)`.
    func replacing(in string: String, transform: (String) -> String) -> String {
        let ns = string as NSString
        var result = ""
        var cursor = 0
        for match in matches(in: string, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            result += transform(ns.substring(with: match.range(at: 1)))
            cursor = match.range.location + match.range.length
        }
        result += ns.substring(from: cursor)
        return result
    }
}
