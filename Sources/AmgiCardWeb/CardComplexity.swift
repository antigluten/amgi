import Foundation

/// Decides whether a rendered card is simple enough for the native SwiftUI
/// renderer (R11). Deliberately conservative: anything off the allowlist —
/// unknown tags, cloze, typed answer, MathJax, content-affecting CSS — routes
/// the card to the WebView so native rendering is never lossy.
public enum CardComplexity {
    /// Tags the native renderer understands. Anything else fails the check.
    private static let allowedTags: Set<String> = [
        "b", "i", "u", "em", "strong", "sub", "sup", "span",
        "div", "p", "br", "hr", "img", "center",
    ]

    /// Markers that require the WebView regardless of tags.
    private static let complexMarkers = [
        "[[type:",       // typed answer
        "class=\"cloze", // cloze deletion
        "class='cloze",
        #"\("#, #"\["#,  // MathJax delimiters
        "<anki-mathjax",
    ]

    /// CSS features that can change *content* (hide/show/inject/reposition),
    /// which the native renderer would silently ignore.
    private static let complexCSSMarkers = [
        "display", "visibility", "content:", "@media", "position",
    ]

    private static let tagRegex = try! NSRegularExpression(pattern: "</?([a-z][a-z0-9-]*)")

    public static func isSimple(renderedFront: String, renderedBack: String, css: String) -> Bool {
        complexityIssue(renderedFront: renderedFront, renderedBack: renderedBack, css: css) == nil
    }

    /// Human-readable reason the card fails the simplicity check, or nil
    /// when it passes. Drives `isSimple` and the reviewer's diagnostics.
    public static func complexityIssue(renderedFront: String, renderedBack: String, css: String) -> String? {
        let html = (renderedFront + "\n" + renderedBack).lowercased()

        for marker in complexMarkers where html.contains(marker) {
            return "marker '\(marker)' in rendered HTML"
        }

        let ns = html as NSString
        let matches = tagRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            let tag = ns.substring(with: match.range(at: 1))
            if !allowedTags.contains(tag) { return "tag <\(tag)> in rendered HTML" }
        }

        let lowerCSS = css.lowercased()
        for marker in complexCSSMarkers where lowerCSS.contains(marker) {
            return "CSS contains '\(marker)'"
        }

        return nil
    }
}
