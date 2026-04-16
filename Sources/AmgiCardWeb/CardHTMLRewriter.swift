import Foundation

public enum CardHTMLRewriter {
    /// Conservative URL-path character set for emitting filenames into HTML
    /// attributes. Removes quotes, angle brackets, and ampersand from the
    /// `.urlPathAllowed` set so a hostile filename cannot break out of the
    /// attribute it is placed into.
    private static let safeFilenameAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "\"'<>&")
        return set
    }()

    public static func rewrite(_ body: String) -> String {
        rewriteImageSrcs(rewriteSoundMarkers(body))
    }

    private static func rewriteSoundMarkers(_ body: String) -> String {
        let pattern = #"\[sound:([^\]]+)\]"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = body as NSString
        var result = ""
        var cursor = 0
        regex.enumerateMatches(in: body, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let filename = ns.substring(with: match.range(at: 1))
            let encoded = filename.addingPercentEncoding(withAllowedCharacters: Self.safeFilenameAllowed) ?? filename
            let id = "amgi-audio-\(UUID().uuidString)"
            result += """
            <button class="amgi-play" onclick="amgiPlay('\(id)')" aria-label="Play audio">\u{25B6}</button>\
            <audio id="\(id)" src="amgi-asset://media/\(encoded)" preload="metadata"></audio>
            """
            cursor = match.range.location + match.range.length
        }
        result += ns.substring(from: cursor)
        return result
    }

    /// Rewrites bare `<img src="X">` (or single-quoted) to
    /// `<img src="amgi-asset://media/X">`. Known scope limits — acceptable for
    /// Anki-rendered card HTML: does not handle unquoted srcs
    /// (`<img src=x.jpg>`) or escaped quotes inside a quoted src
    /// (`src="foo\"bar.jpg"`). Anki's card renderer never emits either.
    private static func rewriteImageSrcs(_ body: String) -> String {
        let pattern = #"<img([^>]*?)\ssrc=(["'])([^"']+)\2"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let ns = body as NSString
        var result = ""
        var cursor = 0
        regex.enumerateMatches(in: body, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            let fullRange = match.range
            let attrs = ns.substring(with: match.range(at: 1))
            let quote = ns.substring(with: match.range(at: 2))
            let src = ns.substring(with: match.range(at: 3))
            result += ns.substring(with: NSRange(location: cursor, length: fullRange.location - cursor))
            let rewritten = rewrittenSrc(src)
            result += "<img\(attrs) src=\(quote)\(rewritten)\(quote)"
            cursor = fullRange.location + fullRange.length
        }
        result += ns.substring(from: cursor)
        return result
    }

    private static func rewrittenSrc(_ src: String) -> String {
        if src.hasPrefix("http://") || src.hasPrefix("https://") ||
           src.hasPrefix("data:") || src.hasPrefix("amgi-asset://") {
            return src
        }
        let encoded = src.addingPercentEncoding(withAllowedCharacters: safeFilenameAllowed) ?? src
        return "amgi-asset://media/\(encoded)"
    }
}
