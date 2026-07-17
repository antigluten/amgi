import Testing
@testable import AmgiApp

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
