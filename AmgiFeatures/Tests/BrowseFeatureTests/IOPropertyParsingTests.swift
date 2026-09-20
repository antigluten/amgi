//
//  IOPropertyParsingTests.swift
//  BrowseFeatureTests
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import Testing
@testable import BrowseFeature

/// The image-occlusion cloze payload is a `:`-joined list of `key=value`
/// tokens. Values are written unescaped, so the parser has to be careful
/// about what counts as the start of the next property.
@Suite("Image-occlusion property parsing")
struct IOPropertyParsingTests {
    @Test("parses a plain rect payload")
    func plainRect() {
        let props = parseIOProperties(from: "left=.1:top=.2:width=.3:height=.4")
        #expect(props["left"] == ".1")
        #expect(props["top"] == ".2")
        #expect(props["width"] == ".3")
        #expect(props["height"] == ".4")
    }

    @Test("keeps the final property's value intact")
    func lastValueNotTruncated() {
        // Regression: anchoring the key pattern to the `:` delimiter moved
        // each match's start onto the colon, so an unadjusted `-1` chopped
        // the last character off every value.
        let props = parseIOProperties(from: "left=.1:fs=24")
        #expect(props["fs"] == "24")
    }

    @Test("text containing letters= is not split into a bogus property")
    func equalsInsideTextValue() {
        // "E=mc2" is routine content for a science deck. Matching a bare
        // ([A-Za-z]+)= treated the `E=` as a new key, truncating the text
        // and inventing a property — silent loss that then synced.
        let props = parseIOProperties(from: "left=.1:top=.2:text=E=mc2:scale=1")
        #expect(props["text"] == "E=mc2")
        #expect(props["E"] == nil)
        #expect(props["scale"] == "1")
    }

    @Test("text containing an equation with digits survives")
    func algebraInsideTextValue() {
        let props = parseIOProperties(from: "text=y=2x+1:fs=18")
        #expect(props["text"] == "y=2x+1")
        #expect(props["fs"] == "18")
    }

    @Test("empty payload yields no properties")
    func emptyPayload() {
        #expect(parseIOProperties(from: "").isEmpty)
    }
}
