/// User-selectable rendering engine for review cards (R11).
/// `auto` defers to `CardComplexity`; the other two force an engine,
/// though cards that *require* the WebView (typed answer, cloze, MathJax,
/// scripts) always render there regardless.
public enum CardRenderEngine: String, CaseIterable, Sendable {
    case auto
    case alwaysNative = "native"
    case alwaysHTML = "html"
}
