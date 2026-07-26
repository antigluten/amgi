import Testing
import AnkiKit

@Suite struct RenderedCardTests {
    @Test func cardCSSField() {
        let r = RenderedCard(frontHTML: "<p>q</p>", backHTML: "<p>a</p>", cardCSS: ".card { color: red; }")
        #expect(r.frontHTML == "<p>q</p>")
        #expect(r.backHTML == "<p>a</p>")
        #expect(r.cardCSS == ".card { color: red; }")
    }

    @Test func cardCSSEmptyDefault() {
        let r = RenderedCard(frontHTML: "f", backHTML: "b", cardCSS: "")
        #expect(r.cardCSS.isEmpty)
    }
}
