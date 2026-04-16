import Foundation
import Testing
@testable import AmgiCardWeb

@Suite struct CardHTMLRewriterTests {
    @Test func plainTextPassesThrough() {
        let input = "<p>Hello, world!</p>"
        #expect(CardHTMLRewriter.rewrite(input) == input)
    }

    @Test func soundMarkerBecomesButtonAndAudio() {
        let output = CardHTMLRewriter.rewrite("Listen: [sound:hello.mp3]")
        #expect(output.contains("class=\"amgi-play\""))
        #expect(output.contains("src=\"amgi-asset://media/hello.mp3\""))
        #expect(output.contains("<audio"))
        #expect(!output.contains("[sound:hello.mp3]"))
    }

    @Test func multipleSoundsGetUniqueIds() {
        let output = CardHTMLRewriter.rewrite("[sound:a.mp3] and [sound:b.mp3]")
        let idPattern = #"id="(amgi-audio-[^"]+)""#
        let regex = try! NSRegularExpression(pattern: idPattern)
        let ns = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: ns.length))
        let ids = matches.map { ns.substring(with: $0.range(at: 1)) }
        #expect(ids.count == 2)
        #expect(Set(ids).count == 2)
    }

    @Test func filenameWithSpacesIsPercentEncoded() {
        let output = CardHTMLRewriter.rewrite("[sound:my sound.mp3]")
        #expect(output.contains("amgi-asset://media/my%20sound.mp3"))
    }

    @Test func emptyFilenameMarkerIsLeftAsIs() {
        // Regex requires at least one character between `:` and `]`, so `[sound:]`
        // is not a valid marker and should pass through verbatim.
        let input = "prefix [sound:] suffix"
        #expect(CardHTMLRewriter.rewrite(input) == input)
    }

    @Test func adjacentMarkersProduceTwoDistinctPlayers() {
        let output = CardHTMLRewriter.rewrite("[sound:a.mp3][sound:b.mp3]")
        #expect(output.components(separatedBy: "<audio").count - 1 == 2)
        #expect(output.components(separatedBy: "class=\"amgi-play\"").count - 1 == 2)
        #expect(!output.contains("[sound:"))
    }

    @Test func maliciousFilenameCannotBreakOutOfAttribute() {
        let hostile = #"evil".mp3"#
        let output = CardHTMLRewriter.rewrite("[sound:\(hostile)]")
        // Double-quote must be percent-encoded, not emitted raw.
        #expect(!output.contains(#""evil".mp3"#))
        #expect(output.contains("evil%22.mp3"))
        // Angle brackets and ampersand likewise.
        let hostile2 = "x<y&z>.mp3"
        let out2 = CardHTMLRewriter.rewrite("[sound:\(hostile2)]")
        #expect(!out2.contains("<y&z>"))
    }

    @Test func bareImgSrcIsRewrittenToMediaScheme() {
        let output = CardHTMLRewriter.rewrite(#"<img src="photo.jpg">"#)
        #expect(output.contains(#"src="amgi-asset://media/photo.jpg""#))
    }

    @Test func absoluteHttpsSrcIsNotRewritten() {
        let input = #"<img src="https://example.com/a.jpg">"#
        #expect(CardHTMLRewriter.rewrite(input) == input)
    }

    @Test func dataUrlSrcIsNotRewritten() {
        let input = #"<img src="data:image/png;base64,AAAA">"#
        #expect(CardHTMLRewriter.rewrite(input) == input)
    }

    @Test func alreadyRewrittenSrcIsIdempotent() {
        let input = #"<img src="amgi-asset://media/x.jpg">"#
        #expect(CardHTMLRewriter.rewrite(input) == input)
    }

    @Test func imageFilenameWithSpacesIsPercentEncoded() {
        let output = CardHTMLRewriter.rewrite(#"<img src="my pic.jpg">"#)
        #expect(output.contains(#"src="amgi-asset://media/my%20pic.jpg""#))
    }

    @Test func imgSrcAsSecondAttributeIsRewritten() {
        let output = CardHTMLRewriter.rewrite(#"<img alt="photo" src="p.jpg">"#)
        #expect(output.contains(#"src="amgi-asset://media/p.jpg""#))
        #expect(output.contains(#"alt="photo""#))
    }

    @Test func singleQuotedImgSrcIsRewritten() {
        let output = CardHTMLRewriter.rewrite("<img src='p.jpg'>")
        #expect(output.contains("src='amgi-asset://media/p.jpg'"))
    }

    @Test func multipleImagesInOneBodyAreAllRewritten() {
        let output = CardHTMLRewriter.rewrite(#"<img src="a.jpg"><p>x</p><img src="b.jpg">"#)
        #expect(output.contains(#"src="amgi-asset://media/a.jpg""#))
        #expect(output.contains(#"src="amgi-asset://media/b.jpg""#))
    }

    @Test func uppercaseImgTagIsRewritten() {
        let output = CardHTMLRewriter.rewrite(#"<IMG SRC="p.jpg">"#)
        #expect(output.contains("amgi-asset://media/p.jpg"))
    }
}
