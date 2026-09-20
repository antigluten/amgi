//
//  CardTextTests.swift
//  AmgiCardWebTests
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import Testing
@testable import AmgiCardWeb

/// `CardText` replaced four mutually inequivalent HTML strippers and three
/// spellings of the `[sound:]` pattern, so these pin the behaviour the
/// surfaces now share.
@Suite("Card text parsing")
struct CardTextTests {
    @Test("strips tags and audio markers")
    func stripsTagsAndMarkers() {
        let html = "<div>Hello <b>world</b></div>[sound:a.mp3]"
        #expect(CardText.plainText(html) == "Hello world")
    }

    @Test("removes style block contents, not just the tags")
    func stripsStyleBlockContents() {
        // Only the watch's stripper did this, so the same note rendered
        // differently there than in the native iOS renderer.
        let html = "<style>.card { color: red; }</style>Front"
        #expect(CardText.plainText(html) == "Front")
    }

    @Test("removes script block contents")
    func stripsScriptBlockContents() {
        let html = "<script>var x = 1;</script>Front"
        #expect(CardText.plainText(html) == "Front")
    }

    @Test("decodes the entities notes actually carry")
    func decodesEntities() {
        #expect(CardText.plainText("a &amp; b &lt;c&gt;") == "a & b <c>")
    }

    @Test("decodes ampersand last so entities aren't double-decoded")
    func ampersandDecodedLast() {
        // "&amp;lt;" should become "&lt;" — literal text — not "<".
        #expect(CardText.plainText("&amp;lt;") == "&lt;")
    }

    @Test("collapses blank runs")
    func collapsesBlankRuns() {
        #expect(CardText.plainText("a<br><br><br>b").contains("a"))
        #expect(!CardText.plainText("a\n\n\nb").contains("\n\n"))
    }

    @Test("extracts sound filenames in order")
    func extractsSoundFilenames() {
        let html = "[sound:one.mp3] middle [sound:two.ogg]"
        #expect(CardText.soundFilenames(in: html) == ["one.mp3", "two.ogg"])
    }

    @Test("sound marker is case-insensitive")
    func soundMarkerIsCaseInsensitive() {
        // Real collections contain [Sound:...]; three of the four previous
        // copies of this pattern missed those.
        #expect(CardText.soundFilenames(in: "[Sound:x.mp3]") == ["x.mp3"])
    }

    @Test("no markers yields no filenames")
    func noMarkers() {
        #expect(CardText.soundFilenames(in: "plain text").isEmpty)
    }
}
