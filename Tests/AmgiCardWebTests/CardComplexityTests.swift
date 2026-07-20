import Testing
@testable import AmgiCardWeb

@Suite struct CardComplexityTests {
    private func isSimple(front: String, back: String = "", css: String = "") -> Bool {
        CardComplexity.isSimple(renderedFront: front, renderedBack: back, css: css)
    }

    @Test func plainTextIsSimple() {
        #expect(isSimple(front: "猫", back: "cat"))
    }

    @Test func allowlistedMarkupIsSimple() {
        #expect(isSimple(
            front: "<div><b>word</b> <i>pos</i></div>",
            back: "<div>front</div><hr><p>answer <em>example</em></p><img src=\"a.jpg\">"
        ))
    }

    @Test func soundMarkerIsSimple() {
        #expect(isSimple(front: "hello [sound:hello.mp3]"))
    }

    @Test func clozeIsComplex() {
        #expect(!isSimple(front: "x <span class=\"cloze\">[...]</span> y"))
    }

    @Test func typedAnswerIsComplex() {
        #expect(!isSimple(front: "word [[type:Back]]"))
    }

    @Test func mathJaxIsComplex() {
        #expect(!isSimple(front: #"euler \(e^{i\pi}\)"#))
        #expect(!isSimple(front: #"block \[x\]"#))
        #expect(!isSimple(front: "<anki-mathjax>x</anki-mathjax>"))
    }

    @Test func disallowedTagsAreComplex() {
        #expect(!isSimple(front: "<script>alert(1)</script>"))
        #expect(!isSimple(front: "<table><tr><td>x</td></tr></table>"))
        #expect(!isSimple(front: "<ruby>漢<rt>かん</rt></ruby>"))
        #expect(!isSimple(front: "<iframe src=\"x\"></iframe>"))
    }

    @Test func complexBackForcesWebView() {
        #expect(!isSimple(front: "fine", back: "<video src=\"x.mp4\"></video>"))
    }

    @Test func contentAffectingCSSIsComplex() {
        #expect(!isSimple(front: "x", css: ".hint { display: none; }"))
        #expect(!isSimple(front: "x", css: "@media (max-width: 400px) { .a { color: red } }"))
        #expect(!isSimple(front: "x", css: ".a { visibility: hidden }"))
        #expect(!isSimple(front: "x", css: ".a::after { content: \"!\" }"))
        #expect(!isSimple(front: "x", css: ".a { position: absolute }"))
    }

    @Test func benignCSSIsSimple() {
        #expect(isSimple(
            front: "x",
            css: ".card { font-family: serif; font-size: 30px; text-align: center; color: #333; background-color: white; }"
        ))
    }

    @Test func caseInsensitiveDetection() {
        #expect(!isSimple(front: "<SCRIPT>x</SCRIPT>"))
        #expect(!isSimple(front: "<span CLASS=\"cloze\">x</span>"))
        #expect(!isSimple(front: "x", css: ".a { DISPLAY: none }"))
    }
}
