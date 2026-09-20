//
//  BrowseSubtitleTests.swift
//  BrowseFeatureTests
//
//  Created by Vladimir Gusev on 03.05.2026.
//

import Testing
@testable import BrowseFeature

@Suite("Note row subtitle composition")
struct BrowseSubtitleTests {

    @Test func bothPresent() {
        #expect(composeNoteSubtitle(notetypeName: "Basic", tags: "math") == "Basic · math")
    }

    @Test func notetypeOnlyWhenTagsBlank() {
        #expect(composeNoteSubtitle(notetypeName: "Basic", tags: "  ") == "Basic")
    }

    @Test func tagsOnlyWhenNoNotetype() {
        #expect(composeNoteSubtitle(notetypeName: nil, tags: "math science") == "math science")
    }

    @Test func nilWhenBothEmpty() {
        #expect(composeNoteSubtitle(notetypeName: nil, tags: "") == nil)
    }
}
