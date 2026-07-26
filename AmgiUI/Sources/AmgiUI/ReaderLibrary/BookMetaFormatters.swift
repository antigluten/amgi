public import Foundation

public enum BookMetaFormatters {
    public static func surname(from author: String?) -> String? {
        guard let author else { return nil }
        let trimmed = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(whereSeparator: { $0.isWhitespace }).last.map(String.init)
    }

    public static func relativeReadingDate(_ date: Date, reference now: Date = .init()) -> String {
        let delta = now.timeIntervalSince(date)
        if delta < 60 * 60 * 24 { return "Today" }
        if delta < 60 * 60 * 48 { return "Yesterday" }

        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: now)
    }
}
