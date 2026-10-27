import Foundation
import Testing
@testable import AppCore

@Suite struct WordSpotlightTests {
    @Test func savedWordOfDayScheduleSurvivesRename() throws {
        let legacy = Data(#"{"profileID":"one","source":"deck","days":[{"date":0,"word":{"noteID":42,"term":"cat","reading":"","meaning":"A cat"}}]}"#.utf8)
        let schedule = try JSONDecoder().decode(WordSpotlightSchedule.self, from: legacy)
        let now = Date(timeIntervalSinceReferenceDate: 0)
        #expect(schedule.word(on: now)?.noteID == 42)
        let saved = try JSONEncoder().encode(schedule)
        let reopened = try JSONDecoder().decode(WordSpotlightSchedule.self, from: saved)
        #expect(reopened.word(on: now)?.term == "cat")
        let object = try #require(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        #expect(object["days"] != nil)
        #expect(object["entries"] == nil)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
    }

    @Test func rotationSurvivesDSTAndExpiresInsteadOfShowingAnOldWord() {
        let words = (1...3).map {
            SpotlightWord(noteID: Int64($0), term: "Word \($0)", reading: "", meaning: "Meaning")
        }
        let schedule = WordSpotlightSchedule.make(
            profileID: "default", source: "deck", words: words, previous: nil,
            now: date(7), calendar: calendar
        )
        #expect(schedule.entries.count == 14)
        #expect(schedule.word(on: date(7), calendar: calendar)?.noteID == 1)
        #expect(schedule.word(on: date(8), calendar: calendar)?.noteID == 2)
        #expect(schedule.word(on: date(9), calendar: calendar)?.noteID == 3)
        #expect(schedule.word(on: date(10), calendar: calendar)?.noteID == 1)
        #expect(schedule.word(on: date(21), calendar: calendar) == nil)
        #expect(schedule.entries[2].date.timeIntervalSince(schedule.entries[1].date) == 23 * 3600)
    }

    @Test func replenishingPreservesTodayAndDoesNotReuseAnotherProfilesSchedule() {
        let words = (1...3).map {
            SpotlightWord(noteID: Int64($0), term: "Word \($0)", reading: "", meaning: "Meaning")
        }
        let previous = WordSpotlightSchedule.make(
            profileID: "one", source: "deck", words: words, previous: nil,
            now: date(7), calendar: calendar
        )
        let refreshed = WordSpotlightSchedule.make(
            profileID: "one", source: "deck", words: words, previous: previous,
            now: date(8), calendar: calendar
        )
        #expect(refreshed.entries.first?.word.noteID == 2)
        let switched = WordSpotlightSchedule.make(
            profileID: "two", source: "deck", words: words, previous: previous,
            now: date(8), calendar: calendar
        )
        #expect(switched.entries.first?.word.noteID == 1)
        // The private one-day anchor survives clearing the active widget during A → B → A.
        let anchor = WordSpotlightSchedule(profileID: "one", source: "deck", entries: Array(refreshed.entries.prefix(1)))
        let returned = WordSpotlightSchedule.make(
            profileID: "one", source: "deck", words: words, previous: anchor,
            now: date(8), calendar: calendar
        )
        #expect(returned.entries.first?.word.noteID == 2)
    }

    @Test func linksRoundTripAndRejectMalformedIdentifiers() throws {
        let link = WordSpotlightLink(profileID: "profile two", noteID: 42)
        #expect(WordSpotlightLink(url: try #require(link.url)) == link)
        #expect(WordSpotlightLink(url: URL(string: "amgi://word?profile=x&note=-1")!) == nil)
        #expect(WordSpotlightLink(url: URL(string: "https://word?profile=x&note=42")!) == nil)
        #expect(WordSpotlightLink(url: URL(string: "amgi://word?note=42")!) == nil)
    }

    @Test func intradayRotationAndManualAdvanceSurviveRefresh() throws {
        let words = (1...5).map {
            SpotlightWord(noteID: Int64($0), term: "Word \($0)", reading: "", meaning: "Meaning")
        }
        let schedule = WordSpotlightSchedule.make(
            profileID: "one", source: "deck", words: words, previous: nil,
            now: date(7, hour: 8), calendar: calendar, intervalHours: 3
        )
        #expect(schedule.word(on: date(7, hour: 8), calendar: calendar)?.noteID == 1)
        #expect(schedule.word(on: date(7, hour: 9), calendar: calendar)?.noteID == 2)
        let next = WordSpotlightSchedule.make(
            profileID: "one", source: "deck", words: words, previous: schedule,
            now: date(7, hour: 10), calendar: calendar, intervalHours: 3, advanceBy: 1
        )
        #expect(next.word(on: date(7, hour: 10), calendar: calendar)?.noteID == 3)
        let refreshed = WordSpotlightSchedule.make(
            profileID: "one", source: "deck", words: words, previous: next,
            now: date(7, hour: 11), calendar: calendar, intervalHours: 3
        )
        #expect(refreshed.word(on: date(7, hour: 11), calendar: calendar)?.noteID == 3)
        #expect(refreshed.word(on: date(7, hour: 12), calendar: calendar)?.noteID == 4)
        #expect(refreshed.word(on: try #require(refreshed.expiration(calendar: calendar)), calendar: calendar) == nil)
        #expect(Set(refreshed.entries.map(\.date)).count == refreshed.entries.count)
    }

    @Test func intradayRotationKeepsElapsedHoursAcrossDSTAndAStoredAnchor() throws {
        let words = (1...5).map {
            SpotlightWord(noteID: Int64($0), term: "Word \($0)", reading: "", meaning: "Meaning")
        }
        let initial = WordSpotlightSchedule.make(
            profileID: "one", source: "deck", words: words, previous: nil,
            now: date(7, hour: 23), calendar: calendar, intervalHours: 3
        )
        let anchor = WordSpotlightSchedule(profileID: "one", source: "deck",
                                           entries: Array(initial.entries.prefix(1)), intervalHours: 3)
        let refreshed = WordSpotlightSchedule.make(
            profileID: "one", source: "deck", words: words, previous: anchor,
            now: date(8, hour: 4), calendar: calendar, intervalHours: 3
        )
        #expect(refreshed.word(on: date(8, hour: 4), calendar: calendar)?.noteID == 3)
        #expect(refreshed.word(on: date(8, hour: 7), calendar: calendar)?.noteID == 4)
        #expect(refreshed.entries[1].date.timeIntervalSince(refreshed.entries[0].date) == 3 * 3600)
    }

    @Test func duplicateNotesAndInvalidIntervalsDoNotBreakRotation() {
        let first = SpotlightWord(noteID: 1, term: "cat", reading: "", meaning: "A cat")
        let second = SpotlightWord(noteID: 2, term: "dog", reading: "", meaning: "A dog")
        let schedule = WordSpotlightSchedule.make(
            profileID: "one", source: "deck", words: [first, first, second], previous: nil,
            now: date(7), calendar: calendar, intervalHours: 0
        )
        #expect(schedule.entries.count == 14)
        #expect(schedule.word(on: date(7), calendar: calendar)?.noteID == 1)
        #expect(schedule.word(on: date(8), calendar: calendar)?.noteID == 2)
        #expect(schedule.word(on: date(9), calendar: calendar)?.noteID == 1)
    }

    @Test func changingSourceDoesNotReuseThePreviousWordsPosition() {
        let words = (1...3).map {
            SpotlightWord(noteID: Int64($0), term: "Word \($0)", reading: "", meaning: "Meaning")
        }
        let previous = WordSpotlightSchedule.make(
            profileID: "one", source: "old-deck", words: words, previous: nil,
            now: date(7), calendar: calendar, advanceBy: 1
        )
        #expect(previous.word(on: date(7), calendar: calendar)?.noteID == 2)
        let changed = WordSpotlightSchedule.make(
            profileID: "one", source: "new-deck", words: words, previous: previous,
            now: date(7), calendar: calendar
        )
        #expect(changed.word(on: date(7), calendar: calendar)?.noteID == 1)
    }
}
