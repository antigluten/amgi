package import Foundation

package struct WordSpotlightSchedule: Codable, Sendable {
    package struct Entry: Codable, Sendable {
        package var date: Date
        package var word: SpotlightWord
    }

    package var profileID: String
    package var source: String
    package var entries: [Entry]
    package var intervalHours: Int?

    private enum CodingKeys: String, CodingKey {
        case profileID, source, intervalHours
        case entries = "days"
    }

    package func expiration(calendar: Calendar = .current) -> Date? {
        guard let last = entries.last else { return nil }
        let hours = intervalHours ?? 24
        return calendar.date(byAdding: hours == 24 ? .day : .hour,
                             value: hours == 24 ? 1 : hours, to: last.date)
    }

    package func word(on date: Date, calendar: Calendar = .current) -> SpotlightWord? {
        guard let expires = expiration(calendar: calendar), date < expires else { return nil }
        return entries.last { $0.date <= date }?.word
    }

    /// Daily rotation follows the calendar; intraday rotation follows elapsed hours across DST.
    package static func make(
        profileID: String, source: String, words: [SpotlightWord], previous: Self?,
        now: Date = .now, calendar: Calendar = .current,
        intervalHours: Int = 24, advanceBy: Int = 0
    ) -> Self {
        var seen = Set<Int64>()
        let words = words.filter { seen.insert($0.noteID).inserted }
        guard !words.isEmpty else { return Self(profileID: profileID, source: source, entries: []) }
        let previous = previous.flatMap { $0.profileID == profileID && $0.source == source ? $0 : nil }
        let hours = [1, 3, 6, 12, 24].contains(intervalHours) ? intervalHours : 24
        let anchor = previous?.entries.last(where: { $0.date <= now })
        let elapsedSlots = anchor.map {
            rotationSteps(since: $0.date, until: now,
                          hours: previous?.intervalHours ?? 24, calendar: calendar)
        } ?? 0
        let wordIndex = firstWordIndex(in: words, after: anchor,
                                       elapsedSlots: elapsedSlots, advanceBy: advanceBy)
        let startDate = firstSlotDate(now: now, anchor: anchor, elapsedSlots: elapsedSlots,
                                      hours: hours, previousHours: previous?.intervalHours, calendar: calendar)
        let entries = makeEntries(words: words, firstWordIndex: wordIndex,
                                  startDate: startDate, hours: hours, calendar: calendar)
        return Self(profileID: profileID, source: source, entries: entries, intervalHours: hours)
    }

    private static func firstWordIndex(
        in words: [SpotlightWord], after anchor: Entry?, elapsedSlots: Int, advanceBy: Int
    ) -> Int {
        let preservedWordIndex = anchor.flatMap { entry in
            words.firstIndex { $0.noteID == entry.word.noteID }
        }
        let automaticAdvance = preservedWordIndex == nil ? 0 : elapsedSlots
        let manualAdvance = max(0, advanceBy)
        return ((preservedWordIndex ?? 0) + automaticAdvance + manualAdvance) % words.count
    }

    private static func firstSlotDate(
        now: Date, anchor: Entry?, elapsedSlots: Int, hours: Int, previousHours: Int?, calendar: Calendar
    ) -> Date {
        // Keep an existing intraday boundary across DST and app refreshes.
        if hours < 24, previousHours == hours, let anchor {
            return anchor.date.addingTimeInterval(Double(elapsedSlots * hours * 3600))
        }
        let today = calendar.startOfDay(for: now)
        guard hours < 24 else { return today }
        let slotOffset = floor(now.timeIntervalSince(today) / Double(hours * 3600))
        return today.addingTimeInterval(slotOffset * Double(hours * 3600))
    }

    private static func makeEntries(
        words: [SpotlightWord], firstWordIndex: Int, startDate: Date, hours: Int, calendar: Calendar
    ) -> [Entry] {
        (0..<(14 * 24 / hours)).compactMap { offset in
            guard let date = calendar.date(byAdding: hours == 24 ? .day : .hour,
                                          value: hours == 24 ? offset : offset * hours, to: startDate)
            else { return nil }
            return Entry(date: date, word: words[(firstWordIndex + offset) % words.count])
        }
    }

    private static func rotationSteps(since anchor: Date, until now: Date, hours: Int, calendar: Calendar) -> Int {
        if hours == 24 {
            let firstDay = calendar.startOfDay(for: anchor)
            let currentDay = calendar.startOfDay(for: now)
            return max(0, calendar.dateComponents([.day], from: firstDay, to: currentDay).day ?? 0)
        }
        return max(0, Int(now.timeIntervalSince(anchor) / Double(hours * 3600)))
    }
}
