import Testing
@testable import AmgiCardWeb

@Suite struct NativeCardContentTests {
    private func texts(_ content: NativeCardContent) -> [String] {
        content.blocks.compactMap {
            if case .text(let attributed) = $0 { return String(attributed.characters) }
            return nil
        }
    }

    @Test func plainTextIsOneBlock() {
        let content = NativeCardContent.parse(html: "猫")
        #expect(texts(content) == ["猫"])
        #expect(content.audioFiles.isEmpty)
    }

    @Test func brSplitsBlocks() {
        let content = NativeCardContent.parse(html: "cat<br>a small feline")
        #expect(texts(content) == ["cat", "a small feline"])
    }

    @Test func divsSplitBlocks() {
        let content = NativeCardContent.parse(html: "<div>front</div><div>back</div>")
        #expect(texts(content) == ["front", "back"])
    }

    @Test func hrBecomesDivider() {
        let content = NativeCardContent.parse(html: "a<hr>b")
        #expect(content.blocks.count == 3)
        #expect(content.blocks[1] == .divider)
    }

    @Test func imgBecomesImageBlock() {
        let content = NativeCardContent.parse(html: "<img src=\"cat.jpg\">")
        #expect(content.blocks == [.image(filename: "cat.jpg")])
    }

    @Test func soundMarkerExtractedNotRendered() {
        let content = NativeCardContent.parse(html: "hello [sound:hello.mp3]")
        #expect(content.audioFiles == ["hello.mp3"])
        #expect(texts(content) == ["hello"])
    }

    @Test func multipleSoundsKeepOrder() {
        let content = NativeCardContent.parse(html: "[sound:a.mp3][sound:b.mp3]")
        #expect(content.audioFiles == ["a.mp3", "b.mp3"])
        #expect(content.blocks.isEmpty)
    }

    @Test func boldSurvivesAsAttributedRun() {
        let content = NativeCardContent.parse(html: "a <b>bold</b> word")
        guard case .text(let attributed) = content.blocks.first else {
            Issue.record("expected text block")
            return
        }
        #expect(String(attributed.characters) == "a bold word")
        let hasBoldRun = attributed.runs.contains { run in
            run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
        }
        #expect(hasBoldRun)
    }

    @Test func italicSurvivesAsAttributedRun() {
        let content = NativeCardContent.parse(html: "an <i>example</i>")
        guard case .text(let attributed) = content.blocks.first else {
            Issue.record("expected text block")
            return
        }
        let hasItalicRun = attributed.runs.contains { run in
            run.inlinePresentationIntent?.contains(.emphasized) == true
        }
        #expect(hasItalicRun)
    }

    @Test func entitiesAreDecoded() {
        let content = NativeCardContent.parse(html: "a &amp; b&nbsp;&lt;c&gt;")
        #expect(texts(content) == ["a & b \u{003C}c\u{003E}"])
    }

    @Test func literalAsterisksAreNotMarkdown() {
        let content = NativeCardContent.parse(html: "2 * 3 * 4")
        #expect(texts(content) == ["2 * 3 * 4"])
    }

    @Test func emptyBlocksAreDropped() {
        let content = NativeCardContent.parse(html: "<div>a</div><div></div><br><div> </div>")
        #expect(texts(content) == ["a"])
    }

    @Test func unknownTagsAreStripped() {
        let content = NativeCardContent.parse(html: "<span style=\"x\">word</span>")
        #expect(texts(content) == ["word"])
    }
}
