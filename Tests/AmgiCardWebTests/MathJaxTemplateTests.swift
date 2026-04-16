import Testing
@testable import AmgiCardWeb

@Suite struct MathJaxTemplateTests {
    @Test func wrapIncludesDoctypeAndHead() {
        let out = MathJaxTemplate.wrap("<p>hi</p>")
        #expect(out.hasPrefix("<!DOCTYPE html>"))
        #expect(out.contains("<head>"))
        #expect(out.contains("</head>"))
    }

    @Test func wrapIncludesMathJaxScript() {
        let out = MathJaxTemplate.wrap("")
        #expect(out.contains("amgi-asset://assets/mathjax/tex-svg.js"))
    }

    @Test func wrapIncludesMathJaxConfig() {
        let out = MathJaxTemplate.wrap("")
        #expect(out.contains("inlineMath"))
        #expect(out.contains("displayMath"))
        #expect(out.contains(#"\\("#))
        #expect(out.contains(#"\\["#))
    }

    @Test func wrapIncludesAmgiPlayHelper() {
        let out = MathJaxTemplate.wrap("")
        #expect(out.contains("function amgiPlay"))
    }

    @Test func wrapEmbedsBodyVerbatim() {
        let body = "<p>Card content with [marker] and <em>emphasis</em></p>"
        let out = MathJaxTemplate.wrap(body)
        #expect(out.contains(body))
    }
}
