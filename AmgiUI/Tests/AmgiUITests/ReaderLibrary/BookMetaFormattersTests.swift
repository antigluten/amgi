import Testing
import Foundation
@testable import AmgiUI

@Suite struct BookMetaFormattersTests {
    @Test func surnameTakesLastWhitespaceToken() {
        #expect(BookMetaFormatters.surname(from: "Antoine de Saint-Exupéry") == "Saint-Exupéry")
        #expect(BookMetaFormatters.surname(from: "Haruki Murakami") == "Murakami")
        #expect(BookMetaFormatters.surname(from: "Miguel de Cervantes") == "Cervantes")
    }

    @Test func surnameOfSingleWordIsThatWord() {
        #expect(BookMetaFormatters.surname(from: "Bulgakov") == "Bulgakov")
    }

    @Test func surnameIsNilForNilOrBlank() {
        #expect(BookMetaFormatters.surname(from: nil) == nil)
        #expect(BookMetaFormatters.surname(from: "   ") == nil)
    }

    @Test func relativeDateToday() {
        let now = Date()
        let label = BookMetaFormatters.relativeReadingDate(now.addingTimeInterval(-3600), reference: now)
        #expect(label == "Today")
    }

    @Test func relativeDateYesterday() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-60 * 60 * 30)
        let label = BookMetaFormatters.relativeReadingDate(yesterday, reference: now)
        #expect(label == "Yesterday")
    }

    @Test func relativeDateFurtherBack() {
        let now = Date()
        let threeDaysAgo = now.addingTimeInterval(-60 * 60 * 24 * 3)
        let label = BookMetaFormatters.relativeReadingDate(threeDaysAgo, reference: now)
        #expect(label.contains("3"))
        #expect(label.lowercased().contains("day"))
    }
}
