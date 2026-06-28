import XCTest
import AnkiKit

final class RenderedCardTests: XCTestCase {
    func testCardCSSField() {
        let r = RenderedCard(frontHTML: "<p>q</p>", backHTML: "<p>a</p>", cardCSS: ".card { color: red; }")
        XCTAssertEqual(r.frontHTML, "<p>q</p>")
        XCTAssertEqual(r.backHTML, "<p>a</p>")
        XCTAssertEqual(r.cardCSS, ".card { color: red; }")
    }

    func testCardCSSEmptyDefault() {
        let r = RenderedCard(frontHTML: "f", backHTML: "b", cardCSS: "")
        XCTAssertTrue(r.cardCSS.isEmpty)
    }
}
